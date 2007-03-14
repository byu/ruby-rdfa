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
    return parser.parse(document,
      :base_uri => options[:base_uri],
      :bnode_namespace => options[:bnode_namespace],
      :collector => options[:collector],
      :bnode_name_generator => options[:bnode_name_generator])
  end

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

  class CounterGenerator
    attr_accessor :namespace
    attr_accessor :prefix

    def initialize(options={})
      @counter = 0
      self.prefix = options[:prefix] ? options[:prefix] : DEFAULT_BNODE_PREFIX
      self.namespace = options[:namespace].nil? ? '' : options[:namespace]
    end

    def generate
      @counter += 1
      "#{self.namespace}#{self.prefix}#{@counter}"
    end
  end

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

      # Start the BFS traversal of the xml document
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

        # Find about
        about = current_node.attributes['about']
        if about.nil? and current_node.name =~ /^(link|meta)$/
          # We have a meta or link element, thus we only traverse
          # to the single parent to search for an about.
          # If the about doesn't exist, then check for the id
          # attribute.
          # Otherwise, create an anonymous name.
          about = current_node.parent.attributes['about']
          if about.nil? and current_node.parent.attributes['id']
            about = "\##{current_node.parent.attributes['id']}"
          end
          about = name_generator.generate if about.nil?
        elsif about.nil?
          tmp_node = current_node.parent
          while about.nil? and !tmp_node.nil?
            about = tmp_node.attributes['about']
            tmp_node = tmp_node.parent
          end
        end
        about = '' if about.nil?
        begin
          about = make_uri(new_ns, base_uri, about)
        rescue StandardError => e
          emit_warning(collector, current_node, e.to_s)
        end

        # Get the href if it exists
        href = nil
        begin
          href = make_uri(new_ns, base_uri, current_node.attributes['href'])
        rescue StandardError => e
          emit_warning(collector, current_node, e.to_s)
        end

        # find and emit the rel statement
        begin
          rel = curie_to_uri(new_ns, current_node.attributes['rel'])
          emit_triple(collector, about, rel, href) if about and rel and href
        rescue StandardError => e
          emit_warning(collector, current_node, e.to_s)
        end

        # find and emit the rev statement
        begin
          rev = curie_to_uri(new_ns, current_node.attributes['rev'])
          emit_triple(collector, href, rev, about) if about and rev and href
        rescue StandardError => e
          emit_warning(collector, current_node, e.to_s)
        end

        # find and emit the property statement
        begin
          property  = curie_to_uri(new_ns, current_node.attributes['property'])
          content = current_node.attributes['content']
          if content.nil? and current_node.children.length > 0
            content = ''
            current_node.children.each do |child|
              content += child.to_s
            end
          end
          emit_triple(collector, about, property, content) if(
            about and property and content)
        rescue StandardError => e
          emit_warning(collector, current_node, e.to_s)
        end

        # Queue up the child elements for processing
        current[:node].elements.each do |child|
          queue << { :node => child, :ns => new_ns }
        end
      end

      return collector.results if collector.respond_to?(:results)
      return collector
    end

    protected
      def emit_base_uri(collector, base_uri)
        if collector and collector.respond_to? :base_uri=
          collector.base_uri = namespace
        end
      end

      def emit_bnode_namespace(collector, namespace)
        if collector and collector.respond_to? :bnode_namespace=
          collector.bnode_namespace = namespace
        end
      end

      def emit_namespace(collector, namespace)
        if collector and collector.respond_to? :add_namespace
          collector.add_namespace(namespace)
        end
      end

      def emit_triple(collector, subject, predicate, object)
        if collector and collector.respond_to? :add_triple
          collector.add_triple(subject, predicate, object)
        end
      end

      def emit_warning(collector, current_node, message)
        if collector and collector.respond_to? :add_warning
          collector.add_warning(message)
        end
        if collector and collector.respond_to? :add_debug
          collector.add_debug(current_node.to_s, message)
        end
      end

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
  end
end
