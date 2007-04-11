
require 'rdfa'

class MyClass
  acts_as_rdfa_parser

  def initialize
    @xml_string = <<EOF
<html>
    <head>
      <title property="dctitle">Dan's home page</title>
      <link rel="related" href="x.jpg" />
      <link rel="related_2" />
      <meta property="subject_is_document">My Literal about Document</meta>
    </head>
    <body rel='document_to_body_rel_no_href'>
      Nothing here.
      <span rev="spanny_to_body_bnode" rel="body_bnode_to_spanny" href="http://example.com/spanny" />
      <link rel="body_bnode_to_link" href="http://example.com/somebodylink" />
      <span id="span2" rel='body_bnode_to_bnode_named_span2'>
        <span rev="span3_to_span2" rel="span2_to_span3" href="http://example.com/span3" />
      </span>
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

