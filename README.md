# femto

A very basic text editor written for educational purposes in plain Ruby with no
dependencies.

I wrote it from memory after watching the "text editor from scratch" [Destroy
All Software][DAS] [screencast][] by [Gary Bernhardt][]. It supports:

* Quitting (`Ctrl-Q`)
* Moving the cursor up/down/right/left (`Ctrl-P`/`N`/`F`/`B`)
* Deleting the character before the cursor, like backspace (`Ctrl-H`)
* Breaking a line (`Enter`)
* Undoing! (`Ctrl-_`)

Additionally, I've implemented:

* Flicker-free screen
* Creating a file if it doesn't exist (not just editing)
* Saving (`Ctrl-S`)
* Moving left (`Ctrl-B`) at the beginning of a line causes the cursor to jump to
  the end of the previous line
* Moving right (`Ctrl-F`) at the end of a line causes the cursor to jump to the
  beginning of the next line
* Moving the cursor to the beginning of the line (`Ctrl-A`)
* Moving the cursor to the end of the line (`Ctrl-E`)
* Deleting the character before the cursor (`Ctrl-H`) at the beginning of a line
  joins lines
* Deleting the character at the cursor, like delete (`Ctrl-D`)
* Deleting the character at the cursor (`Ctrl-D`) when at the end of a line
  joins lines
* Deleting the text before the cursor (`Ctrl-U`)
* Deleting the text after (and including) the cursor (`Ctrl-K`)

[screencast]: https://www.destroyallsoftware.com/screencasts/catalog/text-editor-from-scratch
[DAS]: https://www.destroyallsoftware.com/
[Gary Bernhardt]: https://twitter.com/garybernhardt

## Usage

~~~ sh
ruby femto.rb myfile.txt
~~~

## Disclaimer

This is an experimental program. Do NOT use it to edit files that you don't want
to lose/damage.

## License

[The Unlicense](https://github.com/agorf/femto/blob/master/LICENSE)

## Author

Angelos Orfanakos, <https://agorf.gr/>
