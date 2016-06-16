module Labelling

  extend self

  Points = 2.8346 # per mm 

  # This scaling factor is used to adjust the size of the on-screen canvas
  # to accomodate various font sizes in a fairly realistic manner.
  # The basic dimensions dealt with in this module are for the printed page.
  # The whole canvas will appear on-screen for monitors with at least 1200
  # pixels in the vertical direction.
#  Xscale = 1.36 
  Xscale = 1.00 

#  Default_size = 11
=begin
Removed at version 11.12
     { '8'  =>  8, '9' => 9,  '10' => 10,  '11' => 11,
                    '12' => 12, '13' => 13, '14' => 14, '15' => 15,
                    '16' => 16, '17' => 17, '18' => 18, '20' => 20,
                    '21' => 21, '22' => 22, '24' => 24, '32' => 32,
                    '36' => 36, '48' => 48, '60' => 60, '72' => 72 } 
=end

  # Convert millimetre measures to points.
#  typefaces.each { |f| j = Fonts[f]; Fontdata[j]['scale'] *= Points }  
  Pagesizex = 210.0 * Points
  Pagesizey = 298.0 * Points
  Bottommargin = 15.0 * Points
#  Bottommargin = 0.0 * Points
  Top = 282.0 * Points
  Leftmargin = 7.0 * Points
  Gap = 2.0 * Points

  Disposition = { '3x7'      => [ 3, 7 ],
                  '2x7'      => [ 2, 7 ],
                  '5x13'     => [ 5, 13 ],
                  '2x4'      => [ 2, 4 ],
                  'long'     => [ 1, 1 ],
                  'envelope' => [ 1, 1 ],
                  '4x8'      => [ 4, 8 ] }
=begin
                  'A4'       => [ 1, 1 ],
                  'legal'    => [ 1, 1 ],
                  'envelope' => [ 1, 1 ] }
=end
  Labeltypes = { 'L7159' => '3x7',  'J8160' => '3x7',
                 'L7163' => '2x7',  'J8163' => '2x7',
                 'L7651' => '5x13', 'J8551' => '5x13',
                 'L7165' => '2x4',  'J7165' => '2x4'
               }
                 
  Labelsizes = { }
  # dx dy left_margin gap bottom_margin
# L7159  J8160  63.5 x 38.1  top 15
  Labelsizes['3x7']      = [ 63.5, 38.1, 7.0, 3.0, 13.5 ]
# L7163  J8163  99.1 x 38.1
  Labelsizes['2x7']      = [ 97.8, 38.8, 4.8, 2.1, 15.0 ]
# L7651  J8551  
  Labelsizes['5x13']     = [ 38.1, 21.2, 2.5, 2.625, 11.0 ]
# L7165  J7165  99.1 x 67.7
  Labelsizes['2x4']      = [ 99.1, 67.7, 4.5, 2.8, 13.0 ]
#  Labelsizes['long']     = [ 220.0, 110.0, 0.0, 0.0, 186.0 ]
#  Labelsizes['envelope'] = [ 229.0, 162.0, 0.0, 0.0, 135.0 ]
  Labelsizes['long']     = [ 220.0, 110.0, 0.0, 0.0, 0.0 ]
  Labelsizes['envelope'] = [ 229.0, 162.0, 0.0, 0.0, 0.0 ]
  Labelsizes['4x8']      = [ 51.0, 34.0, 5.0, 0.0, 19.0 ]
  
#  Labelsizes['5x13'] = [ 38.4, 21.0, 5.1, 2.3, 13.0 ]

  Labelsizes.each_key { |k| Labelsizes[k].collect! { |z| z *= Points*Xscale } }
#  Labelsizes.each_key { |k| Labelsizes[k].collect! { |z| z *= Xscale } }

 
  def pagegrid ( disposition )
    width, height, margin, gap, bottom = Labelsizes[disposition]
    puts sprintf( "%f %f %f %f %f\n", width, height, margin, gap, bottom )
    components = Disposition[disposition]
    boxes = [ ]
    if components[1] > 1 then
      m, n = components
      i = 0
#      pagesizey = Pagesizey
      y0 = bottom 
      0.upto( n-1 ).each do |k|
        y1 = y0 + height
        x0 = margin
        0.upto( m-1 ).each do |j| 
          x1 = x0 + width
          boxes[i] = [ x0, y0, x1, y1 ]
          i += 1
          x0 += (width + gap)
        end
        y0 += height
      end
    else
      y0 = bottom 
      y1 = y0 + height
      x0 = margin
      x1 = x0 + width
      boxes[0] = [ x0, y0, x1, y1 ]
    end
    return boxes
  end

  def labelgrid ( disposition )
    width, height, margin, gap, bottom = Labelsizes[disposition]
#    puts sprintf( "%f %f %f %f %f\n", width, height, margin, gap, bottom )
    components = Disposition[disposition]
    boxes = [ ]
    if components[1] > 1 then
      m, n = components
      i = 0
#      pagesizey = (n * height) + bottom
#      pagesizey = Pagesizey
      y0 = bottom 
      m = components[0]
      n = components[1]
      0.upto( n-1 ).each do |k|
        y1 = y0 + height
        x0 = margin
        0.upto( m-1 ).each do |j| 
          x1 = x0 + width
          boxes[i] = [ x0, y0, x1, y1 ]
          i += 1
          x0 += (width + gap)
        end
        y0 += height
      end
    else
      y0 = bottom 
      y1 = y0 + height
      x0 = margin
      x1 = x0 + width
      boxes[0] = [ x0, y0, x1, y1 ]
    end
#      # Defaults to A4 for the time being
#      boxes[0] = [ Leftmargin, Bottommargin, Pagesizex, Pagesizey ] 
    return boxes
  end

  def self.printgrid ( boxes, disposition )
#    components = Disposition[disposition]
    i = 0
#    m = components[0]
#    n = components[1]
    m, n = Disposition[disposition]
#    a = 
    0.upto( n-1 ).each do |k|
#      b = 
      0.upto( m-1 ).each do |j| 
        corners = boxes[i].collect { |z| (z + 0.5).to_i }
#        x0, y0, x1, y1 = corners
#        printf( "%2d : %6.0f %6.0f  %6.0f %6.0f\n", i, x0, y0, x1, y1 )
        printf( "%2d : %6.0f %6.0f  %6.0f %6.0f\n", i, *corners )
        i += 1
      end
      puts "\n"
    end

  end
 
end


