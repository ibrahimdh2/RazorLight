package rzl

import "core:fmt"
import "core:os"
import "core:strings"

import "commands"

// ============================================================================
// RazorLight CLI Tool
// ============================================================================

VERSION :: "0.1.0"

main :: proc() {
	args := os.args[1:]

	if len(args) == 0 {
		print_help()
		return
	}

	command := args[0]
	command_args := args[1:] if len(args) > 1 else []string{}

	switch command {
	case "new":
		commands.cmd_new(command_args)
	case "run":
		commands.cmd_run(command_args)
	case "build":
		commands.cmd_build(command_args)
	case "help", "-h", "--help":
		print_help()
	case "version", "-v", "--version":
		print_version()
	case:
		fmt.printf("Unknown command: %s\n", command)
		fmt.println("Run 'rzl help' for usage information.")
		os.exit(1)
	}
}

print_help :: proc() {
	fmt.println("RazorLight Game Engine CLI")
	fmt.println("")
	fmt.println("Usage: rzl <command> [options]")
	fmt.println("")
	fmt.println("Commands:")
	fmt.println("  new <name>      Create a new RazorLight project")
	fmt.println("  run [target]    Build and run the project (default: game)")
	fmt.println("  build [target]  Build the project without running")
	fmt.println("  help            Show this help message")
	fmt.println("  version         Show version information")
	fmt.println("")
	fmt.println("Examples:")
	fmt.println("  rzl new my_game     Create a new project called 'my_game'")
	fmt.println("  rzl run             Build and run the game")
	fmt.println("  rzl build release   Build release version")
}

print_version :: proc() {
	fmt.printf("RazorLight CLI v%s\n", VERSION)
}
