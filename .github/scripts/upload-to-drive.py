#!/usr/bin/env python3
"""Upload .exe artifacts to a Google Drive folder."""

from __future__ import annotations

import json
import os
import re
import sys

from google.oauth2 import service_account
from google.oauth2.credentials import Credentials
from googleapiclient.discovery import build
from googleapiclient.errors import HttpError
from googleapiclient.http import MediaFileUpload

SCOPES = ["https://www.googleapis.com/auth/drive"]


def erro(msg: str) -> None:
    print(f"::error::{msg}")
    sys.exit(1)


def extrair_folder_id(url: str) -> str:
    m = (
        re.search(r"/folders/([A-Za-z0-9_-]+)", url)
        or re.search(r"[?&]id=([A-Za-z0-9_-]+)", url)
        or re.fullmatch(r"([A-Za-z0-9_-]{10,})", url)  # aceita o ID puro também
    )
    if not m:
        erro(f"Não consegui extrair o ID da pasta da URL: '{url}'")
    return m.group(1)


def autenticar():
    if os.environ.get("GDRIVE_SA_JSON"):
        return service_account.Credentials.from_service_account_info(
            json.loads(os.environ["GDRIVE_SA_JSON"]), scopes=SCOPES
        )

    if os.environ.get("GDRIVE_REFRESH_TOKEN"):
        return Credentials(
            None,
            refresh_token=os.environ["GDRIVE_REFRESH_TOKEN"],
            client_id=os.environ["GDRIVE_CLIENT_ID"],
            client_secret=os.environ["GDRIVE_CLIENT_SECRET"],
            token_uri="https://oauth2.googleapis.com/token",
            scopes=SCOPES,
        )

    erro("Nenhuma credencial configurada (GDRIVE_SA_JSON ou GDRIVE_REFRESH_TOKEN).")


def localizar_exes(artifact_dir: str) -> list[str]:
    return [
        os.path.join(raiz, f)
        for raiz, _, arquivos in os.walk(artifact_dir)
        for f in arquivos
        if f.lower().endswith(".exe")
    ]


def enviar_exes(drive, folder_id: str, pasta_nome: str, exes: list[str]) -> None:
    for caminho in exes:
        nome = os.path.basename(caminho)
        nome_q = nome.replace("\\", "\\\\").replace("'", "\\'")
        existentes = (
            drive.files()
            .list(
                q=f"name = '{nome_q}' and '{folder_id}' in parents and trashed = false",
                fields="files(id)",
                supportsAllDrives=True,
                includeItemsFromAllDrives=True,
            )
            .execute()
            .get("files", [])
        )

        media = MediaFileUpload(
            caminho,
            resumable=True,
            mimetype="application/vnd.microsoft.portable-executable",
        )
        try:
            if existentes:
                arq = (
                    drive.files()
                    .update(
                        fileId=existentes[0]["id"],
                        media_body=media,
                        fields="id,webViewLink",
                        supportsAllDrives=True,
                    )
                    .execute()
                )
                acao = "Atualizado"
            else:
                arq = (
                    drive.files()
                    .create(
                        body={"name": nome, "parents": [folder_id]},
                        media_body=media,
                        fields="id,webViewLink",
                        supportsAllDrives=True,
                    )
                    .execute()
                )
                acao = "Enviado"
        except HttpError as e:
            if "storageQuotaExceeded" in str(e):
                erro(
                    "Contas de serviço não têm cota no 'Meu Drive'. Use um Drive "
                    "compartilhado (Opção A) ou as credenciais OAuth (Opção B)."
                )
            raise

        print(f"{acao}: {nome} -> pasta '{pasta_nome}' | {arq['webViewLink']}")


def main() -> None:
    url = (
        os.environ.get("DRIVE_FOLDER")
        or os.environ.get("PASTA_DRIVE")
        or ""
    ).strip()
    artifact_dir = os.environ.get("ARTIFACT_DIR", "release-assets/windows")

    folder_id = extrair_folder_id(url)
    creds = autenticar()
    drive = build("drive", "v3", credentials=creds, cache_discovery=False)

    try:
        pasta = (
            drive.files()
            .get(
                fileId=folder_id,
                fields="id,name,mimeType",
                supportsAllDrives=True,
            )
            .execute()
        )
    except HttpError as e:
        erro(
            f"Sem acesso à pasta {folder_id} ({e.status_code}). "
            "Confira a URL e se a conta usada tem permissão de edição nela."
        )

    if pasta["mimeType"] != "application/vnd.google-apps.folder":
        erro(f"O link aponta para '{pasta['name']}', que não é uma pasta.")

    exes = localizar_exes(artifact_dir)
    if not exes:
        erro(f"Nenhum .exe encontrado em '{artifact_dir}'.")

    enviar_exes(drive, folder_id, pasta["name"], exes)


if __name__ == "__main__":
    main()
