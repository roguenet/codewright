xml.instruct!
xml.feed "xmlns" => "http://www.w3.org/2005/Atom" do
  xml.title "Rogue Codewright"
  xml.subtitle "Technical musings of Nathan Curtis"
  xml.id "http://codewright.roguenet.org/"
  xml.link "href" => "http://codewright.roguenet.org/"
  xml.link "href" => "http://codewright.roguenet.org/feed.xml", "rel" => "self"
  xml.updated blog.articles.first.date.to_time.iso8601
  xml.author { xml.name "Nathan Curtis" }

  blog.articles[0..5].each do |article|
    xml.entry do
      xml.title article.title
      xml.link "rel" => "alternate", "href" => "http://codewright.roguenet.org" + article.url
      xml.id article.url
      xml.published article.date.to_time.iso8601
      xml.updated article.date.to_time.iso8601
      xml.author { xml.name "Nathan Curtis" }
      xml.summary article.summary, "type" => "html"
      #xml.content article.body, "type" => "html"
    end
  end
end
