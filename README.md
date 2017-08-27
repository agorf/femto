# femto

A minimal text editor written for fun in plain Ruby with no dependencies.

It was written from memory after watching the [relevant screencast][screencast]
by [Gary Bernhardt][] and supports:

* Quitting (`Ctrl-Q`)
* Moving the cursor up/down/right/left (`Ctrl-P`/`N`/`F`/`B`)
* Deleting the character before the cursor, like backspace (`Ctrl-H`)
* Breaking a line (`Enter`)
* Undoing! (`Ctrl--`)

Additionally, the following "features" have been implemented:

* Flicker-free screen
* Creating a file if it doesn't exist (not just editing)
* Ignoring non-printable characters
* Saving (`Ctrl-S`)
* Redoing! (`Ctrl-R`)
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
* Deleting the line text before the cursor (`Ctrl-U`)
* Deleting the line text after (and including) the cursor (`Ctrl-K`)

[screencast]: https://www.destroyallsoftware.com/screencasts/catalog/text-editor-from-scratch
[Gary Bernhardt]: https://twitter.com/garybernhardt

## Usage

~~~ sh
./femto.rb myfile.txt
~~~

## Keyboard shortcuts

* `Ctrl-Q` quits
* `Ctrl-S` saves
* `Ctrl-P` moves the cursor up (mnemonic: previous)
* `Ctrl-N` moves the cursor down (mnemonic: next)
* `Ctrl-F` moves the cursor right (mnemonic: forward)
* `Ctrl-B` moves the cursor left (mnemonic: backward)
* `Ctrl-A` moves the cursor to the beginning of the line
* `Ctrl-E` moves the cursor to the end of the line (mnemonic: end)
* `Ctrl-E` deletes the previous character (backspace)
* `Ctrl-D` deletes the current character (mnemonic: delete)
* `Ctrl-U` deletes the line text before the cursor
* `Ctrl-K` deletes the line text after (and including) the cursor
* `Ctrl--` undoes the last change
* `Ctrl-R` redoes the last change (mnemonic: redo)

## Disclaimer

This is an experimental program. Do NOT use it to edit files that you don't want
to lose/damage.

## License

[The Unlicense](https://github.com/agorf/femto/blob/master/LICENSE)

## Author

Angelos Orfanakos, <https://agorf.gr/>
