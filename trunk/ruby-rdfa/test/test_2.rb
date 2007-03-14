
require 'rdfa'

class MyClass
  acts_as_rdfa_parser

  def initialize
    @xml_string = <<EOF
<html>
    <head>
      <title property="dctitle">Dan's home page</title>
      <link rel="related" href="x.jpg" />
      <meta property="subject_is_document">My Literal about Document</meta>
    </head>
    <body>
      Nothing here.
      <link rel="subject_is_bnode" href="http://example.com/" />
    </body>
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

