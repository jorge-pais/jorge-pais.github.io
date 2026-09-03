# My portfolio/blog page

Build the webpage using make. Make sure you have the necessary linux utilities: bash 4.0+, pandoc, python, e.t.c.

```bash 
make all   # build the website
make serve # build and serve to localhost:8080
```

Access it on the github pages link: [jorge-pais.github.io](https://jorge-pais.github.io)

## Development log

TODO: While migrating to pandoc + makefile, i no longer have the gruvbox themed syntax highlighting (i still have the css file). Pandoc supports custom themes as such:

```bash
pandoc --list-highlight-styles
pandoc -o my.theme --print-highlight-style pygments
# we can then edit the theme to match what we want
pandoc --syntax-highlighting my.theme
```

Check the [pandoc syntax-highlighting](https://pandoc.org/demo/example33/15-syntax-highlighting.html) documentation for more information on this
