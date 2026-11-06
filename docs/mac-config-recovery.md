# Recover an Intel Mac configuration

MeshCore Bot stores its settings at `~/Library/Application Support/MeshCore Bot/config.ini`.

When the built-in editor saves a changed configuration, it first stages a backup and preserves the previous contents as `config.ini.bak`. Keep your own separate backup before major changes.

1. Quit MeshCore Bot and verify the bot subprocess is stopped.
2. In Finder choose **Go → Go to Folder**, enter `~/Library/Application Support/MeshCore Bot/`, and press Return.
3. Copy `config.ini` and `config.ini.bak` to a safe location before making changes.
4. To restore the last backup, rename the current `config.ini` to `config.ini.problem`, then duplicate `config.ini.bak` and name the duplicate `config.ini`.
5. Reopen MeshCore Bot, inspect **Edit Config**, and test bot startup. Do not post configuration files publicly because they may contain secrets or private mesh information.

If the backup is missing, restore your own saved configuration or start from the bundled example. A passing CI build does not validate a particular radio's connection settings.
