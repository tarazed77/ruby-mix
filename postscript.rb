module Postscript

  extend self

  Xscale = 1.0

  def resolve_textblock ( screed )
    i = j = k = 0
    n = screed.length
    lines = [ ]
    buffer = screed
    while k < n do
      j = buffer.index( "\n" )
      break if !j
#      puts buffer.slice( 0..j-1 )
      lines << buffer.slice( 0..j-1 )
      k += j
      break if k >= n
      buffer = buffer.slice( j+1..-1 )
    end
    lines
  end

  # This is a hack to get round the problem of some fonts being
  # incorrectly named in the Postscript output.
  # It has been dropped in current versions (> 10.0)
  def psrepair ( screed, repairs )
    repairs.each { |a, b| screed.gsub!( a, b ) if screed.index( a ) }
    screed
  end

  def psrevert ( screed )
    screed.gsub!( "findfont -", "findfont " )
    screed
  end

#  def postscript ( c, fontmap, file )
  def postscript ( c, file )
    colourmap = { }
    # Tweak the output color
    colourmap['blue']  = [ 0.1, 0.1, 0.9, 'setrgbcolor' ]
    colourmap['green'] = [ 0.1, 0.7, 0.1, 'setrgbcolor' ]
    colourmap['red']   = [ 0.9, 0.1, 0.1, 'setrgbcolor' ]

    xheight = 842 * Postscript::Xscale
    xwidth = 595 * Postscript::Xscale
    # Position the text at the corner of the page defined by x and y
    # Keep the Postscript page in memory for further processing.
    # The fontmap parameter has been dropped because X fonts are no longer handled
    # directly.
    screed = c.postscript( 'colormap' => colourmap,
      'pageheight' => 842, 'pagewidth' => 595, 'pagex' => 0, 'pagey' => 0, 
      'height' => xheight, 'width' => xwidth, 'x' => 0, 'y' => 0,
      'pageanchor' => 'sw'  )
#    abc = psrepair( screed, ::Repairs )
    newfile = File.new( file, 'w' )
    newfile.puts screed
    newfile.close
  end

end
