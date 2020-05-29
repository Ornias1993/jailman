# Plex

### Config Parameters:
- beta: set to `true` if you want to run the plex beta (previously known as "plexpass"). Please note: This is not required for plexpass features

#### Advanced config parameters:
- ramdisk: Specify the `size` parameter to create a transcoding ramdisk under /tmp_transcode. Requires manual setting it un plex to be used for transcoding. (optional)


#### Experimental config parameters:

These parameters are either not fully tested or expected to break with short-term OS updates. They are included in the release however, because they are suspected to become stable eventually.

- hw_transcode: set this to "true" to enable hardware transcoding on compatible systems, to "false" to disable or, preferable, just leave it out to disable
- hw_transcode_ruleset: the devfs rulesetnumber to use for hardware transcoding
- ruleset_script: The location to save the ruleset-setting script to. (loaded at reboot)


# Original plex install script guide

https://www.ixsystems.com/community/resources/fn11-3-iocage-jails-plex-tautulli-sonarr-radarr-lidarr-jackett-transmission-organizr.58/

For more information about plex, please see the Plex website.