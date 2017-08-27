# das-editor

A very basic text editor written for educational purposes in plain Ruby with no
dependencies.

It is based on the "text editor from scratch" [Destroy All Software][DAS]
[screencast][] by [Gary Bernhardt][] which supports:

* Quitting (`Ctrl-Q`)
* Moving the cursor up/down/right/left (`Ctrl-P`/`N`/`F`/`B`)
* Deleting the character before the cursor, like backspace (`Ctrl-H`)
* Breaking a line (`Enter`)
* Undoing! (`Ctrl-_`)

Additionally, I've also implemented:

* Saving (`Ctrl-S`)
* Deleting the character at the cursor, like delete (`Ctrl-D`)
* Moving the cursor to the beginning of the line (`Ctrl-A`)
* Moving the cursor to the end of the line (`Ctrl-E`)
* Deleting the text before the cursor (`Ctrl-U`)
* Deleting the text after (and including) the cursor (`Ctrl-K`)

[screencast]: https://www.destroyallsoftware.com/screencasts/catalog/text-editor-from-scratch
[DAS]: https://www.destroyallsoftware.com/
[Gary Bernhardt]: https://twitter.com/garybernhardt

## Usage

~~~ sh
ruby editor.rb myfile.txt
~~~

## Disclaimer

This is an experimental program. Do NOT use it to edit files that you don't want
to lose/damage.

## License

[The Unlicense](https://github.com/agorf/das-editor/blob/master/LICENSE)

## Author

Angelos Orfanakos, <https://agorf.gr/>
