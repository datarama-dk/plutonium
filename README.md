Plutonium: A Static HTML Generator
==================================
Greetings, gentlebeings!

Plutonium is a HTML generator written in Scheme. It has its name solely so that
I can proudly and truthfully claim that my website is *powered by plutonium*.

It's entirely static, which means that Plutonium-based sites are *fast*.
There's no database, no dynamic server logic, no nonsense. Just static HTML
files that can be spewed into the aether as fast as your favourite HTTP server
can send them. Pure bliss.

Of course, this also strictly limits what you can actually *do* with
Plutonium-based sites, but its particular feature set happens to be precisely
what I need for my site at `datarama.dk`. It is free software; you are free to
read the code and twist it to your own foul ends if you want. Provided, of
course, that you can read Scheme and that your foul ends can be served by a
rather simple static HTML generator. See the file COPYING for further details.

There's no fancy manual, although I have included a fragment of my own website
sources you can base your mad designs on. You'll probably want to write some
CSS to go with the template. Read the code for enlightenment. 

Compiling
---------
You can run Plutonium from the Chicken interpreter if you want, but it'll run
lots faster if you compile it. To compile it, run the following command: 
    
    csc plutonium.scm -o plutonium

Usage
-----
Plutonium can be run standalone from the command line, but is at its best when
combined with the wonderful VimWiki — this is how I intended it, and, quelle
surprise, how I use it.

Because it's integrated with vimwiki, which has a rather verbose parameter
structure, it's unfortunately rather awkward to use from the command line:

plutonium FORCE FORMAT SUFFIX OUTDIR INFILE

    FORCE is currently ignored.
    FORMAT must be the string markdown.
    SUFFIX is whatever file suffix you've configured Vimwiki to use.
    OUTDIR is the full path of the directory Plutonium should generate into.
    INFILE is the full path of the Markdown file you want to HTMLize.

Setting it up to work with Vimwiki is much easier. Put the following in your
.vimrc and you're good to go:

    let g:vimwiki_list = [{"path": SRCDIR, 
                           "path_html": OUTDIR,
                           "syntax": 'markdown',
                           "ext": SUFFIX,
                           "custom_wiki2html": 'plutonium'}]

Where SRCDIR is the directory you want to keep your wiki ﬁles in. If you add
`"auto_export": 1` to the above, Vimwiki will regenerate your HTML on ﬁle save.

NOTE: I suggest you use a custom suffix (I use `pu`) rather than markdown or
md, or Vim will think all Markdown ﬁles are wiki ﬁles. This is especially
important if you use `auto_export`.

Read the code for further enlightenment.
