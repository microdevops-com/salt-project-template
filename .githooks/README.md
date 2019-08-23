.githooks is NOT default dir for hooks.
Default dir is .git/hooks which cannot be synced to remote.
Config file core.hooksPath param works only with git 2.9+, so we use symlinks for activation:
```
cd repo
ln -s ../../.githooks/post-merge .git/hooks/post-merge
```
