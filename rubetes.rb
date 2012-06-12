#!/usr/bin/env ruby

require 'tzinfo'

csvdir = "/home/sam/dblogs"
lastdir = "#{csvdir}/#{Dir::entries(csvdir).sort[-1]}"
csvfile = "#{lastdir}/#{Dir::entries(lastdir).sort[-1]}"

class Event
  def initialize csvline
    @bits = csvline.split ','
    @ordinality = "%05d" % @bits[0]

    fix_date
  end


  def to_s
    s = ''
    s << @date
    s << ", "
    s << @time

    s
  end

  private

  def fix_date
    @timestamp = Time.parse "#{@bits[1]}#{@bits[2]}"
    @unixtime = @timestamp.to_i
    @date = @timestamp.strftime "%F"
    @time = @timestamp.strftime "%T"
    @tzoffset = @timestamp.strftime "%z"
  end
end

file = File.new(csvfile, "r")
while (line = file.gets)
  e = Event.new line
  puts e
end
file.close
