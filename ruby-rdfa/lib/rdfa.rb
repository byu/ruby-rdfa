# Copyright 2007 Benjamin Yu <http://foofiles.com/>
#
#   Licensed under the Apache License, Version 2.0 (the "License");
#   you may not use this file except in compliance with the License.
#   You may obtain a copy of the License at
#
#       http://www.apache.org/licenses/LICENSE-2.0
#
#   Unless required by applicable law or agreed to in writing, software
#   distributed under the License is distributed on an "AS IS" BASIS,
#   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#   See the License for the specific language governing permissions and
#   limitations under the License.
#

#
# Project Home: http://code.google.com/p/ruby-rdfa/
#

require 'rexml/document'
require 'uri'

def acts_as_rdfa_parser
  self.module_eval do
    def parse(source, options={})
      RdfA.parse(source, options)
    end
  end
end

module RdfA
  DEFAULT_BNODE_NAMESPACE = 'tag:code.google.com,2007-03-13:p/ruby-rdfa/bnode#'
  DEFAULT_BNODE_PREFIX = '_a'

  def self.parse(source, options={})
    parser = RdfAParser.new

    document = REXML::Document.new(source)
    raise 'No root element for xml document' if document.root.nil?
    return parser.parse(document,
      :base_uri => options[:base_uri],
      :bnode_namespace => options[:bnode_namespace],
      :collector => options[:collector],
      :bnode_name_generator => options[:bnode_name_generator])
  end


  # ScreenCollector is an Ruby-RDFa collector that prints RDF
  # statements to the screen
  class ScreenCollector
    attr_accessor :print_debug

    def initialize(options={})
      @print_debug = options[:print_debug].nil? ? false : options[:print_debug]
    end

    def base_uri=(uri)
      puts "# base_uri set to '#{uri}'"
    end

    def bnode_namespace=(namespace)
      puts "# BNode Namespace: #{namespace}"
    end

    def add_namespace(namespace)
      puts "# Namespace Added: #{namespace}"
    end

    def add_triple(subject, predicate, object)
      if object.is_a? String
        puts "<#{subject}> <#{predicate}> \"#{object}\" ."
      elsif object.is_a? URI
        puts "<#{subject}> <#{predicate}> <#{object.to_s}> ."
      else
        puts "# Error: triple given where object is neither String nor URI"
        puts "# <#{subject}> <#{predicate}> #{object} ."
      end
    end

    def add_warning(message)
      puts "# Warning: #{message}"
    end

    def add_debug(xml, message)
      puts "# Debug: #{message}"
      puts "# Debug XML: #{xml}"
    end
  end


  # DictionaryCollector is a Ruby-RDFa that stores emitted RDFa statements
  # into a dictionary object.
  class DictionaryCollector
    attr_accessor :base_uri
    attr_accessor :bnode_namespace
    attr_reader :namespaces
    attr_reader :triples
    attr_reader :warnings
    attr_reader :debug

    def initialize
      self.base_uri = nil
      self.bnode_namespace = nil
      @namespaces = []
      @triples = {}
      @warnings = []
      @debug = []
    end

    def add_namespace(namespace)
      @namespaces.push(namespace) unless @namespaces.include?(namespace)
    end

    def add_triple(subject, predicate, object)
      subject_store = self.triples[subject.to_s]
      if subject_store.nil?
        subject_store = {}
        @triples[subject.to_s] = subject_store
      end
      object_list = subject_store[predicate.to_s]
      if object_list.nil?
        object_list = []
        subject_store[predicate.to_s] = object_list
      end
      object_list << object
    end

    def add_warning(message)
      @warnings << message
    end

    def add_debug(xml, message)
      @debug << [xml, message]
    end

    def results
      self
    end
  end


  # CounterGenerator is a generic bnode name generator that uses
  # an autoincrementing field to distinguish new nodes.
  #
  # NOTE: This Counter remembers the generated bnode URI for a given
  #       rexml node.
  class CounterGenerator
    attr_accessor :namespace
    attr_accessor :prefix

    def initialize(options={})
      self.reset
      self.prefix = options[:prefix] ? options[:prefix] : DEFAULT_BNODE_PREFIX
      self.namespace = options[:namespace].nil? ? '' : options[:namespace]
    end

    def generate(node)
      if @bnode[node].nil?
        @counter += 1
        @bnode[node] = @counter
      end
      "#{self.namespace}#{self.prefix}#{@bnode[node]}"
    end

    def reset
      @bnode = {}
      @counter = 0
    end
  end


  # RdfAParser is the workhorse RDFa parser.
  #
  class RdfAParser

    def parse(document, options={})
      # Obtain runtime settings from options
      collector = options[:collector]
      collector = DictionaryCollector.new unless collector
      name_generator = options[:anon_name_generator]
      name_generator = CounterGenerator.new unless name_generator

      base_uri = options[:base_uri]
      if base_uri
        base_uri = URI.parse(base_uri)
        raise 'base_uri must be an absolute URI' unless base_uri.absolute?
      end

      anon_namespace = options[:anon_namespace]
      anon_namespace = DEFAULT_BNODE_NAMESPACE unless anon_namespace

      name_generator.namespace = anon_namespace

      # Give the bnode namespace to the collector
      emit_bnode_namespace(collector, anon_namespace)

      # Special Case: see if we have an xhtml document with a head.
      #   If so, we need to treat link and meta about differently.
      # Start the BFS traversal of the xml document
      head = nil
      # using each_element is supposed to be faster xpath way in rexml
      document.each_element('/html/head') do |element|
        head = element
      end

      queue = []
      queue << { :node => document.root, :ns => {'_' => anon_namespace} }
      while queue.length > 0
        current = queue.shift

        new_ns = current[:ns].dup
        current_node = current[:node]

        # Discover the new namespace declarations
        current_node.attributes.each do |name, value|
          index = name =~ /^xmlns:/
          begin
            ns = URI.parse(value.strip)
            raise "namespaces must be absolute URIs: #{value}" if ns.relative?
            new_ns[name[6,name.length]] = ns.to_s
            emit_namespace(collector, ns.to_s)
          rescue StandardError => e
            emit_warning(collector, current_node, e.to_s)
          end unless index.nil?
        end

        # Queue up the child elements for processing
        current[:node].elements.each do |child|
          queue << { :node => child, :ns => new_ns }
        end

        # Pull out the attributes needed for the skip test.
        rel = current_node.attributes['rel']
        rev = current_node.attributes['rev']
        property = current_node.attributes['property']

        # We skip to next node when there are zero RDFa predicates
        next if(rel.nil? and rev.nil? and property.nil?)

        # Pull out other important RDFa attributes
        href = current_node.attributes['href']
        content = current_node.attributes['content']

        begin
          # Find about uri.
          #
          # We have special cases if the current node is a link or meta.
          # In addition, we must check to see if a link or meta is
          # within the head of an xhtml document (max_traversal of 1).
          about_uri = nil
          link_meta = current_node.name =~ /^(link|meta)$/
          # if link_meta is not-nil, then max_traversal is 1; else nil.
          max_traversal = (link_meta and 1) or nil
          about_node = find_about_node(current_node, max_traversal)
          # We now determine if the about_node is the head of an
          # xhtml document. If so, then we have to handle this naming
          # in a special way.
          is_head = (link_meta and head and about_node == head) ? true : false
          about_pre = about_uri_from_node(name_generator, about_node, is_head)
          # Now normalize the about uri.
          about_uri = make_uri(new_ns, base_uri, about_pre)
        rescue StandardError => e
          emit_warning(collector, current_node, e.to_s)
        end

        # Get the href
        href_uri = nil
        begin
          # Make an href uri from the href attribute
          href_uri = make_uri(new_ns, base_uri, href)
          # We find the ID or anonymous bnode uri if we have a rel
          # or rev in this node and no href.
          if(href_uri.nil? and (rel or rev))
            href_uri = bnode_uri_from_node(name_generator, current_node)
          end
        rescue StandardError => e
          emit_warning(collector, current_node, e.to_s)
        end

        # find and emit the rel statement
        begin
          rel_uri = curie_to_uri(new_ns, rel)
          emit_triple(collector, about_uri, rel_uri, href_uri) if rel_uri
        rescue StandardError => e
          emit_warning(collector, current_node, e.to_s)
        end

        # find and emit the rev statement
        begin
          rev_uri = curie_to_uri(new_ns, rev)
          emit_triple(collector, href_uri, rev_uri, about_uri) if rev_uri
        rescue StandardError => e
          emit_warning(collector, current_node, e.to_s)
        end

        # find and emit the property statement
        begin
          property_uri  = curie_to_uri(new_ns, property)
          # If no content attribute, then we just take the xml of the
          # current node's children.
          if content.nil? and current_node.children.length > 0
            content = ''
            current_node.children.each do |child|
              content += child.to_s
            end
          end
          emit_triple(collector, about_uri, property_uri, content) if(
            property_uri and content)
        rescue StandardError => e
          emit_warning(collector, current_node, e.to_s)
        end
      end

      return collector.results if collector.respond_to?(:results)
      return collector
    end

    protected

      # figures out the uri, which could be made from a CURIE or
      # which may be normalized with a namespace and base uri.
      def make_uri(namespaces, base_uri, value)
        if value.nil?
          return nil
        elsif value =~ /^\[.*\]$/
          return curie_to_uri(namespaces, value[1,value.length-2])
        else
          u = URI.parse(value)
          return (u.relative? and base_uri ) ? base_uri + u : u
        end
      end

      # Executes the RDFa about resolution process to find the node
      # from which we can pull out an about uri.
      #
      # [startnode] -- the current node being processed
      # [max_traversal] -- the number of ancestors to check, or nil to
      #   check them all.
      #
      # returns nil if the about should reflect the document itself.
      #
      def find_about_node(startnode, max_traversal=nil)
        # We traverse up the tree until one of the following:
        # 1. We find the first about attribute of an ancestor
        # 2. We find a rev or rel attribute in an element without an href.
        # 3. We hit the document root.
        current_node = startnode
        count = 0
        until current_node.nil?
          about = current_node.attributes['about']
          rel = current_node.attributes['rel']
          rev = current_node.attributes['rev']
          href = current_node.attributes['href']

          # We're done if there's an about
          return current_node if about

          # Check to see if we have a rev or rel with nil href.
          # But only for ancestors of the startnode
          return current_node if(
            current_node != startnode and (rel or rev) and href.nil?)

          # We return if we hit max_traversal number of ancestors.
          count += 1
          return current_node if(max_traversal and count > max_traversal)

          # We keep going
          current_node = current_node.parent
        end
        # We went all the way way up to nil.
        return nil
      end

      # Pulls out the about URI from the node that we care about.
      #
      # [node] -- The node returned by a call to find_about_node.
      # [is_head] -- The node we are given is the head of an xhtml document.
      #
      def about_uri_from_node(name_generator, node, is_head)
        # return '' because the node is nil, which means the about uri
        # is the Document itself.
        return '' if node.nil?
        about = node.attributes['about']
        # We have an about attribute, so we use that
        return about if about
        # Else, the node passed to us is of the following:
        # 1. The link/meta's parent which may be head of xhtml document.
        #    This implies: about=""
        # 2. Some other parent node of a link or meta element.
        # 3. An ancestor node that has a rel or rev while lacking
        #    an href.
        return '' if is_head
        return bnode_uri_from_node(name_generator, node)
      end

      # We either return the bnode uri, or an ID URI fragment given
      # a node.
      #
      # [name_generator] -- name generator
      # [node] -- The current node from which to make the name.
      #
      # returns a URI string.
      def bnode_uri_from_node(name_generator, node)
        id = node.attributes['id']
        return "\##{id}" if id
        return name_generator.generate(node)
      end

      # Create a URI string based on a CURIE
      #
      def curie_to_uri(namespaces, value)
        return nil unless value

        split_value = value.split(':')
        case split_value.length
        when 1
          return URI.parse(value)
        when 2
          uribase = namespaces[split_value[0]]
          if uribase.nil?
            raise "invalid curie, namespace prefix not found for #{value}"
          end
          return URI.parse(uribase + split_value[1])
        else
          raise "invalid curie value: #{value}"
        end
      end


      # helper function to emit an RDFa parsing event to the collector.
      def emit_base_uri(collector, base_uri)
        if collector and collector.respond_to? :base_uri=
          collector.base_uri = namespace
        end
      end

      # helper function to emit an RDFa parsing event to the collector.
      def emit_bnode_namespace(collector, namespace)
        if collector and collector.respond_to? :bnode_namespace=
          collector.bnode_namespace = namespace
        end
      end

      # helper function to emit an RDFa parsing event to the collector.
      def emit_namespace(collector, namespace)
        if collector and collector.respond_to? :add_namespace
          collector.add_namespace(namespace)
        end
      end

      # helper function to emit an RDFa parsing event to the collector.
      def emit_triple(collector, subject, predicate, object)
        if collector and collector.respond_to? :add_triple
          collector.add_triple(subject, predicate, object)
        end
      end

      # helper function to emit an RDFa parsing event to the collector.
      def emit_warning(collector, current_node, message)
        if collector and collector.respond_to? :add_warning
          collector.add_warning(message)
        end
        if collector and collector.respond_to? :add_debug
          collector.add_debug(current_node.to_s, message)
        end
      end
  end
end
