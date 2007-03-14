
require 'rdfa'

class MyClass
  acts_as_rdfa_parser

  def initialize
    @xml_string = <<EOF
<html xmlns:geo="http://www.w3.org/2003/01/geo/" xmlns:dc="http://d.com/"
  xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
  xmlns:foaf="http://xmlns.com/foaf/0.1/"
  >
    <head>
      <title property="dc:title">Dan's <blah/> home page</title>
      <link about="x.jpg" rel="foaf:based_near" href="x.jpg" />
    </head>
    <body>
      <section xmlns:fark="http://fark.com/ ">
        <link rel="fark:type" href="[foaf:Person]" />
      </section>
      <section id="person" xmlns:fark="http://ddd.com/">
        <span about="[_:geolocation]">
          Dan is located at latitude
          <meta property="geo:lat">51.47026</meta>
          and longitude
          <meta property="geo:long">-2.59466</meta>
        </span>
        <link rel="rdf:type" href="[foaf:Person]" />
        <link rel="foaf:homepage" href="[foaf:homepage]" />
        <link rel="foaf:based_near" href="[_:geolocation]" />
        <h1 property="foaf:name">Dan Brickley</h1>
      </section>

      <!-- Both rel and rev -->
      <super about="http://about.example.com/" rel="rel_property"
        rev="rev_property" href="http://href.example.com/" />

      <!-- the next one is unseen -->
      <super about="http://XXXXXd.com/" rev="notfoundprefix:localname" />

      <!-- this will emit a warning, since namespaces must be absolute URI -->
      <section xmlns:fark="/ddd.com/">
        <link rel="fark:type" href="[foaf:Person]" />
      </section>
    </body>
</html>
EOF
  end

  def do_work_1
    puts " ==== Doing do_work_1 ===="
    y = parse(@xml_string, :base_uri => 'http://fark.com/')

    y.triples.each do |subject, predicates|
      puts subject
      predicates.each do |predicate, object_list|
        puts "\t#{predicate}"
        object_list.each do |object|
          if object.is_a? URI
            puts "\t\t<#{object}>"
          else
            puts "\t\t\"#{object}\""
          end
        end
      end
    end

    puts " ==== Debug of do_work_1 ===="
    y.debug.each { |xml, value| puts "#{value} #{xml}" }
  end

  def do_work_2
    puts " ==== Doing do_work_2 ===="
    parse(@xml_string, :collector=>RdfA::ScreenCollector.new)
  end
end

x = MyClass.new
x.do_work_1
x.do_work_2

