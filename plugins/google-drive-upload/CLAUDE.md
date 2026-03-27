# Google Drive Upload

Upload files from Claude directly to Google Drive. Supports all file types: Word docs, PDFs, spreadsheets, presentations, and more.

## Available Tools/Skills

- **Upload file to Drive** - Upload any file with automatic folder creation and duplicate handling
- **Organize by folder** - Auto-create folder hierarchy or use existing folders
- **Replace existing files** - Overwrite files by name in same folder
- **Works in Cowork** - Seamless integration with Cowork MCP environment

## Configuration

- **Required setup**: Google Apps Script web app (creates shareable upload endpoint)
- **Config file**: `~/.cowork-gdrive-config.json` with auth token and Drive folder ID
- **One-time setup**: Script guides through OAuth flow to populate config
- **Access**: Available in Claude Code and Cowork sessions

## Common Workflows

1. **Upload Generated File**
   - Claude creates file (PDF report, CSV, Word doc, etc.)
   - Call upload tool with file path
   - Specify Drive folder (auto-creates if needed)
   - File appears in Google Drive immediately

2. **Organize by Project**
   - Create folder structure in Drive first
   - Reference folder names in upload calls
   - Tool auto-creates subfolders if they don't exist
   - Later uploads to same project go to same folder

3. **Update Existing Document**
   - Upload file with same name to same folder
   - Tool replaces previous version (by name)
   - Keep version history in Drive settings if needed

## Best Practices

- **Set up config once** - Config stored locally, persists across sessions
- **Use meaningful folder names** - Auto-created folders inherit names you provide
- **Batch uploads** - Upload multiple files efficiently in one session
- **Leverage Drive sharing** - Share folders with team; permissions auto-apply to new uploads
- **Monitor quota** - Google Drive free tier has storage limits; manage space if needed
- **Version files intentionally** - Use timestamps or version numbers in filenames for old versions
