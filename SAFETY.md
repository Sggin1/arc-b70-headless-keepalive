# Before you run these scripts

Both scripts are short PowerShell files; read them first. Neither downloads anything, uses credentials, or sends data
off the machine.

1. **`keepalive.ps1` only talks to `127.0.0.1`.** It posts a one-token request to your local `llama-server`. Keep the
   server on localhost; nothing here asks you to expose it to the network.
2. **`-ExecutionPolicy Bypass`.** The README uses it so the script runs for that one process only. If you have already
   allowed local scripts, you don't need it. It's your call after reading the file.
3. **`Unblock-File`.** Suggested only if Windows blocks a downloaded copy. It removes the "downloaded from the internet"
   mark, so use it only on a script you've read.
4. **`watch_arc.ps1` stops every running `llama-server`.** On startup (unless `-NoStart` is used) and on its low-RAM
   abort it force-stops all `llama-server` processes on the machine, not just its own. Don't run it while a model you
   care about is serving. It is only a test sampler; the fix doesn't need it.
5. **Auto-start from a shared folder.** If you point a startup entry or scheduled task at a script, keep the script in
   a folder only you can write to. Anyone who can edit it can change what runs at login.
