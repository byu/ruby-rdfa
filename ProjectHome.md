# Features #
  1. Pure Ruby (Using default core libraries)
  1. Simple as possible, No Feature Overkill.
  1. Safely ignores invalid RDFa statements (e.g.- Bad CURIEs, invalid URIs). Instead, the parser emits warning and debug messages to the 'Collector'
  1. Extensible by allowing developers create their own custom 'Collectors' to add bridge data coming from the RDFa parser to the developers' own RDF stores.
  1. Has a mixin method:
```
  require 'rdfa'
  class MyClass
    acts_as_rdfa_parser
  end
  c = MyClass.new
  source = '<xml/>'
  results = c.parse(source)
```

# Special Notes #
  1. CURIE'd about and href attributes can be used to reference anonymous nodes. For example, about='[_:name]' will produce an anonymous node for name.
```
  <div id='person'>
    <span about='[_:geolocation]'>
      <meta property='geo:lat'>51.47026</meta>
      <meta property='geo:long'>-2.59466</meta>
    </span>
    <link rel='foaf:based_near' href='[_:geolocation]' />
  </div>
```
  1. Anonymous Resources (BNodes) are placed in a custom namespace:
```
    tag:code.google.com,2007-03-13:p/ruby-rdfa/bnode#
```
> > One can override this in the parameters.
  1. Because RDFa uses CURIEs, we do not use QNames in the RDF statements-- everything is a URI object or literal text.
  1. About URI resolution work correctly for link and meta elements that are found in the head of an html document. Any xml document that has html as its root element, not just the ones that have the xhtml decl.
  1. Subversion commit [r7](https://code.google.com/p/ruby-rdfa/source/detail?r=7) adds Nested RDFa support._

# Limitations #
  1. xml:base is completely ignored.
  1. Ignores Reification, but will output anonymous nodes in a special way.
  1. The RDFa Specification is still in flux, so please bear with.
  1. Nest CURIEs are not supported.
  1. Literal text are the only supported object datatype (as the content) for RDFa property statements; xml fragments are converted to a string.
