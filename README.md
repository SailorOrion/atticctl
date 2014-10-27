atticctl
========

This is a small bash script to manage attic backups on local file systems

The configuration of an individual repository is stored in $HOME/.attic/configs

If no configuration file is given, default values are assumed:
The default repository is located at /Backups/$(hostname -s) and backs up the root file system only.
