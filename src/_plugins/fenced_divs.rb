Jekyll::Hooks.register [:pages, :documents], :pre_render do |doc|
	doc.content = doc.content.gsub(/:::([^\n]*)\n(.*?):::/m) do
		attrs = $1.strip
		inner = $2.gsub(/\n/, "\n\n")
		%(<div markdown="1" class="paragraph" #{attrs}>\n#{inner}\n</div>)
	end
end
