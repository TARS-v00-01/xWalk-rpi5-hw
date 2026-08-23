# Optional local SearXNG

This deployment is optional. Jarvis continues to answer from local Ollama when
SearXNG is absent or web search is disabled. The compose mapping exposes only
`127.0.0.1:8080`; JSON is the only enabled result format, and unnecessary
plugins are disabled. Expect additional memory, storage, and outbound network
use from the container and selected search engines.

Installing Podman or pulling a SearXNG image requires explicit network and, when
packages are missing, administrator approval. No image is downloaded by the
repository during builds or host tests. Before starting, copy `compose.yaml`
and `settings.yml` to `$HOME/.local/share/xwalk/searxng`, copy the systemd unit
to `$HOME/.config/systemd/user`, and create a mode-600
`$HOME/.config/xwalk/searxng.env` containing a reviewed image tag and a randomly
generated private `SEARXNG_SECRET`.

```bash
systemctl --user daemon-reload
systemctl --user enable --now xwalk-searxng
systemctl --user status xwalk-searxng --no-pager
journalctl --user -u xwalk-searxng --no-pager
curl 'http://127.0.0.1:8080/search?q=xwalk&format=json'
systemctl --user stop xwalk-searxng
```

The service never embeds credentials and does not select an uncontrolled public
instance. Set `voice_active_car_gpt_web_search_enabled = false` to remove the
runtime dependency entirely.
