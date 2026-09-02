---
layout: post
title: Migrating from Jekyll to Pandoc templates
date: 2026-08-30
tags: 
    - Programming
categories:
    - projects

permalink_name: projects
---

There are several ways to generate static webpages, either from markdown or rst; examples of such include jekyll and hugo. These are natively supported by github pages, and have direct integration with github actions. 

But there are several problems that come with these solutions, at least for me I have been using Jekyll for this static webpage, and it was fun at first, but now I just find it frustrating. Having to deal with brittle Gemfiles is just a pain in the ass, and to be honest I feel that I could do better (or do worse if I create a flaky gh actions pipeline). I recently got a macintosh computer and when it came to develop my blog, I didn't even want to begin to think how I would install ruby and gems or whatever on it.

> I am aware that the awesome homebrew project is written in ruby, which means that I probably already have it on my new machine. But all the struggles I have faced regarding ruby gems (and having multiple package managers in general) will forever haunt me and guide this sort of decisions. Possibly for the worse. 

Also, Haskell is now 60 years old! So what better way to celebrate (almost 3 months late), than by showing some love for what is possbily the biggest open source project written in this language.

## Pandoc experiments

So I found out I can just take the markdown articles I have already written and add convert them directly into html using the following command:

```bash
 pandoc --toc --standalone --mathjax -f markdown -t html _posts/article.md -o ~/teste.html
```

This is the combination of command arguments that got pandoc to actually convert markdown to html and keep the MathJax working properly. 

Then this should be easy right? I can already convert the markdown to an html file, it should be now a matter of adding and html template for having the navigation hyperlinks, and apply the same css style.

## The html template

Jekyll's templating is built on Liquid, so my old theme was scattered across a `_layouts/` folder (`default.html`, `post.html`, `page.html`, ...) and an `_includes/` folder for the bits that got reused (`head.html`, `header.html`, `footer.html`, `navlinks.html`, `sharelinks.html`). All of that gets glued together at build time by whatever Jekyll and its plugins decide to do, which is exactly the kind of magic I was trying to get away from.

Pandoc has its own (much simpler) templating scheme. And in the end it turns out I don't need most of what Liquid was doing for me, as a single flat file per "kind of page" is enough with `$variable$` placeholders and `$if(...)$` blocks instead of Liquid tags:

```html
<title>$if(title)$$title$ - $endif$Jorge Pais</title>
...
$if(prev_url)$
  <a class="post_navi-item nav_prev" href="$prev_url$" title="$prev_title$">
```

So now I have `templates/page.html` for static pages (index, resume, articles) and `templates/post.html` for blog posts, and that's it. No more `_layouts` inheriting from `_layouts`, no more mystery includes.

One thing I actually wanted to add, that Jekyll never gave me for free without a plugin, was a prev/next post navigation at the bottom of each article. Pandoc doesn't know anything about "collections" the way Jekyll does, so there's no built-in concept of "the post before this one". I ended up writing a small bash script (`tools/build-posts.sh`) that sorts all the files in `_posts/` by filename (which works because they're all prefixed with `YYYY-MM-DD`), and then, for every post, computes the previous and next slug and passes them into pandoc as `--variable`:

```bash
if [[ $i -gt 0 ]]; then
  prev="${posts[$((i-1))]}"
  ptitle=$(grep -m1 '^title:' "$prev" | sed 's/^title:[[:space:]]*//;s/^"//;s/"$//')
  nav_args+=(--variable "prev_url=/projects/$py/$pm/$pd/$pslug/")
  nav_args+=(--variable "prev_title=$ptitle")
fi
```

It's crude (grepping the title out of the front matter with sed instead of an actual YAML parser is not exactly elegant) but it works, and it's mine, which is more than I can say about half the Jekyll plugins I had installed and never fully understood. I'm still not fully happy with how I've written it, and may change this at some point in the future.

> One issue that this script has, that probably perpetuates the package manager _shitshow_ that I was trying to avoid, is that this uses the `mapfile` feature from bash. The problem is that Mac OS ship with a super outdated version of bash (i think 3.2) while the mapfile command was added in bash 4. Which is from 2009 btw...  

The one thing I did lose is the automatic tag/category archive. In Jekyll, `articles.md` used to just loop over `site.tags` and generate the whole list of posts grouped by tag for free. With Pandoc there's no such concept, so `articles.md` is now a hand-maintained list of links, grouped by category, that I update every time I publish something new. I could write a script that regenerates this file automatically as part of the build/deploy step, scanning the front matter of every post the same way `build-posts.sh` already does for the prev/next titles. But honestly, I'm just too lazy right now, and with the current rate at which I publish articles, updating a markdown list by hand is not exactly a bottleneck.

## The styling

The CSS side of things was, thankfully, the easiest part. My old theme was written in SCSS (`main.scss`), which meant Jekyll had to run it through a Sass compiler on every build. Since I no longer need Jekyll for anything, there's no reason to keep a build step just to flatten a couple of `@import`s, so I just compiled it once and committed the resulting `main.css` as a plain stylesheet.

> Funnily enough, the sass compiler I had used was also a ruby gem...

The only real adjustments needed were around syntax highlighting. Jekyll uses Rouge, which wraps highlighted code in a `.highlight` div, whereas Pandoc wraps it in `div.sourceCode` and generates the actual highlighting classes itself via `--highlight-style=breezedark`. So all the code-block rules that used to only target `.highlight pre` now also target `div.sourceCode pre`:

```css
.highlight pre,
div.sourceCode pre {
    margin: 0;
    padding: 1em;
    background-color: #1d2021;
    border-radius: 4px;
    overflow-x: auto;
}
```

And of course, since I added the prev/next navigation described above, I needed a bit of new CSS to make it not look like garbage:

```css
.post_navi { display: flex; justify-content: space-between; margin: 20px 0; }
.post_navi-item { display: flex; align-items: center; gap: 8px; padding: 8px;
                   border: dashed 1px rgba(219, 219, 219, 0.4); max-width: 45%; }
.nav_next { flex-direction: row-reverse; text-align: right; margin-left: auto; }
```

Everything else, the color palette, the fonts, the general monospace terminal look, carried over untouched. Turns out most of my CSS was never actually Jekyll-specific.

## The markdown

This is the part I was the most worried about going in, and it ended up being the least painful. The front matter block at the top of every post (the YAML between the two `---` fences) is not a Jekyll-specific format, it's just YAML that Jekyll happens to read, and Pandoc happily exposes the same fields as template variables. So almost nothing needed to change there, apart from small details like `permalink_name: /projects` becoming `permalink_name: projects`, since Pandoc treats it as a literal string substituted into the template rather than a routing directive.

The actual markdown content needed a couple of small fixes, mostly because Kramdown (Jekyll's markdown renderer) is more forgiving than Pandoc about whitespace around display math. A block like this used to render fine in Jekyll with no blank line before or after it:

```markdown
$$v_4 = \frac{R_B}{R_B + R_A} v_3$$
$$v_4 = \left(\frac{R_B}{R_B + R_A}\right) \left( \frac{R_5}{R_4} + 1 \right) (-V_t) \log{v_{in}} $$
```

but Pandoc wants a blank line between consecutive `$$...$$` blocks, otherwise it gets confused about where one equation ends and the next begins. I also had a couple of leftover Obsidian-style image embeds (`![[LogAntiLogSchematic.png]]`) that I'd never bothered cleaning up since Jekyll silently ignored them; Pandoc, correctly, does not, so those got converted to normal markdown image syntax.

To keep some inline HTML that a couple of older posts rely on working, the build uses the `markdown+smart+raw_html` Pandoc reader instead of plain `markdown`, which is the other half of the puzzle (together with `--mathjax`) that got the math rendering correctly in that very first experiment.

## Wrapping up

The whole thing came together in a `Makefile` that builds the static pages, the posts (via `build-posts.sh`), and copies over the css/images/favicon, plus a `serve` target that just runs `python3 -m http.server` on the output for local testing. The GitHub Actions workflow shrank down to three real steps: install pandoc, run `make`, upload the artifact:

```yaml
- name: Install pandoc
  run: sudo apt-get install -y pandoc
- name: Build site
  run: make
```

No Gemfile, no Gemfile.lock, no bundler, no Ruby version to babysit across my Linux machine and the Mac. Just `pandoc` and a Makefile, which is honestly all this website ever needed. I'll post about it when it breaks :)

### References

- This article was inspired by the following blog post by freddie sanchez: [freddiesanchez.dev](https://www.freddiesanchez.dev/posts/static-site-using-makefile.html)
- Handling Mathjax when converting markdown to html in pandoc: [stackoverflow](https://stackoverflow.com/questions/37533412/md-with-latex-to-html-with-mathjax-with-pandoc/55106932#55106932) 
- Template documentation pandoc: [pandoc.org](https://pandoc.org/demo/example33/6-templates.html)

