
require 'rdfa'

class MyClass
  acts_as_rdfa_parser

  def initialize
    @xml_string = <<EOF
<html>
    <head id="headid_before_implied_doc">
      <title property="doc_to_literal">home page</title>
      <link rel="head_to_link" href="x.jpg" />
      <link rel="head_to_link" id="linkid" />
      <meta property="head_to_meta">Meta Property Literal is about head</meta>
    </head>
</html>
EOF
  end

  def do_work_1
    puts " ==== Doing do_work_1 ===="
    y = parse(@xml_string)

    y.triples.each do |subject, predicates|
      puts "<#{subject}>"
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
  end

  def do_work_2
    puts " ==== Doing do_work_2 ===="
    y = parse(@xml_string, :base_uri => 'http://example.com/')

    y.triples.each do |subject, predicates|
      puts "<#{subject}>"
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
  end

end

x = MyClass.new
x.do_work_1
x.do_work_2

