<?xml version="1.0" encoding="utf-8"?>
<xsl:stylesheet version="1.0" 
 xmlns:xsl="http://www.w3.org/1999/XSL/Transform" 
 xmlns:wix="http://wixtoolset.org/schemas/v4/wxs">

  <xsl:output method="xml" indent="yes" omit-xml-declaration="yes" />

  <xsl:strip-space elements="*"/>

  <!-- 1. Copia tudo por padrão (Identity Transform) -->
  <xsl:template match="@*|node()">
    <xsl:copy>
      <xsl:apply-templates select="@*|node()"/>
    </xsl:copy>
  </xsl:template>

  <!-- 2. Define a chave para encontrar o ID do componente que contém o EXE -->
  <xsl:key name="ExeComponentId" 
           match="wix:Component[wix:File[@Source='$(var.PublishDir)\Desktop.Import.exe']]" 
           use="@Id" />

  <!-- 3. Remove o Componente que contém o arquivo EXE -->
  <xsl:template match="wix:Component[wix:File[@Source='$(var.PublishDir)\Desktop.Import.exe']]" />

  <!-- 4. Remove a Referência (ComponentRef) desse componente dentro do ComponentGroup -->
  <!-- Isso é crucial para evitar o erro WIX0094 -->
  <xsl:template match="wix:ComponentRef[key('ExeComponentId', @Id)]" />

</xsl:stylesheet>