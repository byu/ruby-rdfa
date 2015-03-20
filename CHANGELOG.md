# 2007 April 08, [r8](https://code.google.com/p/ruby-rdfa/source/detail?r=8) #
  * fixed bug where a URI object wasn't being created for hrefs.
  * changed link/meta about override in head to precedence as stated in mailing list: non-blank about, id, then blank about
  * added test case

# 2007 April 07, [r7](https://code.google.com/p/ruby-rdfa/source/detail?r=7) #

  * Added support for RDFa Nested Structures. That is, xml elements that have a rel or rev without an href attribute.

# 2007 March 14, [r6](https://code.google.com/p/ruby-rdfa/source/detail?r=6) #

  * Initial import of code. With limitations:
    1. xml:base is completely ignored.
    1. Ignores Reification, but will output anonymous nodes in a special way.
    1. The RDFa Specification is still in flux, so please bear with.
    1. Nest CURIEs are not supported.
    1. Literal text are the only supported object datatype (as the content) for RDFa property statements; xml fragments are converted to a string.