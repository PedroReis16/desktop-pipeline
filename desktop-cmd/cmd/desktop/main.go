package main

import (
	"fmt"
	"os"

	"github.com/spf13/cobra"
)

// version e' injetada em tempo de build via -ldflags "-X main.version=...".
var version = "0.0.0-dev"

func main() {
	rootCmd := &cobra.Command{
		Use:   "desktop",
		Short: "Desktop CLI",
		Long:  "Interface de linha de comando do Desktop.",
	}

	versionCmd := &cobra.Command{
		Use:   "version",
		Short: "Mostra a versao da aplicacao",
		Run: func(cmd *cobra.Command, args []string) {
			fmt.Println(version)
		},
	}

	rootCmd.AddCommand(versionCmd)
	rootCmd.Version = version

	if err := rootCmd.Execute(); err != nil {
		os.Exit(1)
	}
}
