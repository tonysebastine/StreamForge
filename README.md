# StreamForge

Open-source streaming automation for live relays, multi-platform RTMP output, VOD recording and processing, Telegram server control, health monitoring, disk monitoring, and systemd automation.

## Highlights

- Twitch-to-RTMP relay using Streamlink + FFmpeg
- Multiple RTMP destinations with FFmpeg FIFO recovery
- Automated VOD assembly with intro/outro assets and MP4 validation
- Telegram allowlist with confirmation for stop/restart
- Disk and service monitoring
- systemd services and timers
- Secrets kept outside Git in /etc/streamforge
- Dedicated streamforge Linux service account

## Quick start

```bash
git clone https://github.com/tonysebastine/StreamForge.git
cd StreamForge
sudo ./install.sh
```

Configure /etc/streamforge/streamforge.env, stream-keys.env, and telegram.env. Add licensed intro.mp4 and outro.mp4 under /opt/streamforge/assets.

Then run `streamforge check` and `streamforge status`. Start the relay only after configuration is complete.

## Layout

/opt/streamforge = code; /etc/streamforge = configuration; /var/lib/streamforge = recordings and VOD output; /var/log/streamforge = logs.

## Security

Never commit stream keys, Telegram tokens, private URLs, recordings, or production logs. Telegram exposes predefined operations only and requires confirmation for destructive relay actions.

## License

MIT
