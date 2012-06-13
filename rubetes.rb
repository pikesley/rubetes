#!/usr/bin/env ruby

require 'tzinfo'

csvdir = "/home/sam/dblogs"
lastdir = "#{csvdir}/#{Dir::entries(csvdir).sort[-1]}"
csvfile = "#{lastdir}/#{Dir::entries(lastdir).sort[-1]}"

class Event < Hash
  def initialize hash
    self.update hash
  end

  def to_s
    s = ""
    self.each_pair do |k, v|
      s << "%010s: " % k
      s << v.to_s
      s << "\n"
    end

    s
  end
end

class Glucose < Event
  def initialize hash
    super hash
  end
end

class Medication < Event
  def initialize hash
    super hash
  end
end

class Weight < Event
  def initialize hash
    super hash
  end
end

class Food < Event
  def initialize hash
    super hash
  end
end

# OnTrack uses really shitty date formats
def fix_date a, b
  h = {}

  t = Time.parse "#{a}#{b}"
  h[:timestamp] = t
  h[:unixtime] = t.to_i
  h[:day] = t.strftime "%A"
  h[:date] = t.strftime "%F"
  h[:time] = t.strftime "%T"
  h[:tzoffset] = t.strftime "%z"

  h
end

events = {}
file = File.new(csvfile, "r")
while (line = file.gets)
  bits = line.split ","
  h = {}
  h[:serial] = "%05d" % bits[0].to_i
  h.update fix_date bits[1], bits[2]
  h[:type] = bits[3]
  h[:subtype] = bits[4] if not bits[4] == ""
  h[:tag] = bits[5] if not bits[5] == ""
  h[:value] = bits[6].to_f

  notes = bits[7][1..-3]
  h[:notes] = notes if not notes == ""

  case h[:type]
  when "Glucose"
    e = Glucose.new h
  when "Medication"
    e = Medication.new h
  when "Weight"
    e = Weight.new h
  when "Food"
    e = Food.new h
  end
  events[h[:serial]] = e
end
file.close

events.keys.sort.each do |k|
  puts events[k]
  puts ""
end

#require 'pp'
#pp events
