## Changes in `history_playlist_enhanced_v3.1.lua`

The `history_playlist_enhanced_v3.1.lua` script has been updated to consolidate the features of `history_playlist_v2.lua` and `history_playlist_CSV.lua`. `history_playlist_enhanced_v3.1.lua` has been enhanced by integrating the play and skip count tracking feature from `history_playlist_v2.lua` and the `like` rating system from `history_playlist_CSV.lua`. 

1. **Data Structure**: The `store` table now holds `playcount`, `skipcount`, `like`, and `time` for each song. This combines the tracking of play and skip counts from `v2` with the `like` rating system from the `CSV` version.

2. **Like Rating Calculation**: A new function `calculate_like` has been introduced to compute a `like` rating based on `playcount` and `skipcount`. This rating is clamped between 0 and 200.

3. **Like Rating Adjustment**: Two functions, `adjust_like_on_skip` and `adjust_like_on_full_play`, adjust the `like` rating when a song is skipped or played fully, respectively.

4. **Initialization**: The `init_playlist` function initializes the `played` table with `like` ratings calculated from the `store` data. It also updates the `like` rating based on the time elapsed since the last play.

5. **Randomization**: The `randomize_playlist` function has been updated to sort songs based on their `like` ratings, with higher-rated songs having a higher chance of being placed higher in the playlist.

6. **Data File Handling**: The `load_data_file` function reads song data from a CSV file and populates the `store` table. The `save_data_file` function writes the updated song data back to the CSV file.

7. **Playing Status Changes**: The `playing_changed` listener function has been modified to update `playcount` or `skipcount` and adjust the `like` rating accordingly when a song ends or is skipped.

8. **Authorship**: The `descriptor` function now includes both the original and current authors, acknowledging the contributions of both.

9. **Path Separator**: The `activate` function determines the path separator based on the operating system, ensuring compatibility with both Windows and Unix-like systems.

10. **Logging**: The script uses a consistent logging prefix `[HShuffle]` for all messages, aiding in debugging and user feedback.

These changes aim to create a more sophisticated and user-responsive playlist shuffling experience in VLC, leveraging both historical play data and dynamic `like` ratings to curate the listening experience.



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


