# CSV Format Guide

This guide shows you how to format a CSV file so you can upload your
song catalog to **DJMagic.io**.

The good news: the format is very simple.

------------------------------------------------------------------------

## Quick Start

Your CSV only needs **two columns**:

-   **title**
-   **artist**

That's it. Once those are present, you can upload your file.

Example:

    title,artist
    Bohemian Rhapsody,Queen
    Hotel California,Eagles

If you want, you can also include a few optional columns to add more
detail (explained below).

------------------------------------------------------------------------

## Columns

  -----------------------------------------------------------------------
  Column            Required?                Description
  ----------------- ------------------------ ----------------------------
  **title**         Yes                      The song title

  **artist**        Yes                      The performer or artist

  **version**       No                       Version of the song (useful
                                             for karaoke): Original,
                                             Acoustic, Duet, Key +2, etc.

  **album**         No                       Album name (for display
                                             only)

  **id**            No                       Your own identifier if you
                                             track songs with an external
                                             ID
  -----------------------------------------------------------------------

### Example with all columns

    title,artist,version,album,id
    Bohemian Rhapsody,Queen,Original,A Night at the Opera,SC-1001
    Bohemian Rhapsody,Queen,Key -2,A Night at the Opera,SC-1002
    Don't Stop Believin',Journey,Duet,Escape,SC-1003
    Sweet Caroline,Neil Diamond,Acoustic,,SC-1004

------------------------------------------------------------------------

## Header Rules

A few simple rules for the first row (the header):

-   Your file **must include a header row**
-   Header names are **case-insensitive** (`Title`, `TITLE`, and `title`
    all work)
-   Extra spaces are automatically trimmed
-   Columns can appear in **any order**
-   Extra columns are allowed --- they'll just be ignored

------------------------------------------------------------------------

## When Uploads Fail

Your upload will be rejected if there are basic formatting problems,
such as:

-   **Missing required columns**\
    Both `title` and `artist` must exist in the header.

-   **Blank title or artist**\
    Every row needs both values.

-   **Duplicate column names**\
    For example: two columns both named `title`.

-   **Empty header cells**\
    Header cells can't be blank.

If something goes wrong, DJMagic will show clear error messages
explaining **what happened and which rows caused the problem**, so you
can fix it quickly.

------------------------------------------------------------------------

## Optional Columns

Optional columns can be left blank.

Example:

    title,artist,version,album,id
    Yesterday,The Beatles,,,
    Imagine,John Lennon,Original,Imagine,

------------------------------------------------------------------------

## Karaoke Tip: Using the Version Column

If you host karaoke, the **version** column is useful for offering
multiple versions of the same song so singers can choose what works best
for them.

Example:

    title,artist,version
    Don't Stop Believin',Journey,Original
    Don't Stop Believin',Journey,Key -2
    Don't Stop Believin',Journey,Duet
    Total Eclipse of the Heart,Bonnie Tyler,Original
    Total Eclipse of the Heart,Bonnie Tyler,Acoustic
    Total Eclipse of the Heart,Bonnie Tyler,Key +3

Common version labels include:

-   Original
-   Acoustic
-   Live
-   Duet
-   Key +1 / Key -1
-   Key +2 / Key -2
-   Explicit
-   Clean

------------------------------------------------------------------------

## Limits

  Resource                                 Limit
  ---------------------------------------- ------------
  Maximum file size                        100 MB
  Maximum rows per catalog                 1,000,000
  Maximum catalogs per account             100
  Maximum total rows across all catalogs   10,000,000

------------------------------------------------------------------------

## Uploading Updates

Uploading a new CSV to an existing catalog will **replace the entire
catalog**.

Don't worry --- the current catalog stays active while the new file is
processed. Your audience can keep searching and requesting songs during
the update.
