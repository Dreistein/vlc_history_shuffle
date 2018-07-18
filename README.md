
# VLC History based shuffling for Playlists

This Plugin shuffles Songs based on the history of playing.
If a song got played recently, it is less likely to get played.
This reduces the chance that the same song gets played again. Even when the media player gets restarted!

## How it works

The plugin creates a file in the vlc config directory, which stores the paths to the songs, the liking and the time of the last change.

At the beginning, all songs get a rating of 100 and the current timestamp.  
When a song gets played, the rating is reduced between 7 and 13 points.  
When a song gets skipped, the rating is reduced by the percentage of the remaining time (up to 10% to the end) ±3 random points

When the plugin randomizes the playlist, songs with a higher rating, have a higher chance to get into the top spots of the playlist.
Songs with less rating are more down in the playlist. Additionally, songs with the same rating get shuffled. So it's always random.

The rating increases when the plugin gets loaded. The rating increases by 1 point every day the song wasn't played.

## Footnotes

I wrote this plugin for personal use and enjoy to use it :)
If you have suggestions for this plugin, feel free to open an issue.  

If you want to buy me a coffee, [feel free to do](https://paypal.me/dreistein101) so.
