#!/usr/bin/env ruby

require 'tzinfo'
require 'mongo'
require 'optparse'

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
      if not k == '_id' then
        s << "%010s: " % k
        s << v.to_s
        s << "\n"
      end
    end

    s
  end
end

class Glucose < Event
  def initialize hash
    super hash

    if self[:value] < 4.0 then
      self[:crash] = true
    end
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
def fix_date d
  h = {}

  t = Time.parse d
  h[:timestamp] = t
  h[:unixtime] = t.to_i
  h[:day] = t.strftime "%A"
  h[:date] = t.strftime "%F"
  h[:time] = t.strftime "%T"
  h[:tzoffset] = t.strftime "%z"

  h
end

options = {}
optparse = OptionParser.new do |opts|
  opts.banner = "Usage: rubetes.rb [options] [csv_file]"

  options[:crash] = false
  opts.on('-c', '--crash', 'Report on BG crashes') do
    options[:crash] = true
  end

  options[:type] = nil
  opts.on('-t', '--type TYPE', 'Show only TYPE data') do |t|
    options[:type] = t
  end

  options[:go_back_days] = nil
  opts.on('-g', '--go-back-days N', 'Go back N days') do |n|
    options[:go_back_days] = n
  end

  options[:for_date] = nil
  opts.on('-d', '--date DATE', 'Show date DATE') do |d|
    options[:for_date] = fix_date(d)[:date]
  end

  opts.on( '-h', '--help', 'Display this screen' ) do
    puts opts
    exit
  end
end

optparse.parse!

if options[:go_back_days] && options[:for_date] then
  puts "-t and -d are mutually exclusive"
end

connection = Mongo::Connection.new
db = connection.db("rubetes")
collection = db.collection("events")

if ARGV[0] then
  file = File.new(ARGV[0], "r")
  while (line = file.gets)
    bits = line.split ","
    h = {}
    h[:serial] = bits[0].to_i #"%05d" % bits[0].to_i
    h.update fix_date "#{bits[1]}#{bits[2]}"
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
    collection.update({:serial => e[:serial]}, e, {:upsert => true})
  end
  file.close
end

query = {}
if options[:for_date] then
  query[:date] = options[:for_date]
end

if options[:go_back_days] then
  target_date = (Time.now - (86400 * options[:go_back_days].to_i)).strftime "%F"
  query[:date] = {"$gt" => "#{target_date}"}
end

if options[:type] then
  query[:type] = options[:type]
end

if options[:crash] then
  query[:type] = 'Glucose'
  query[:crash] = true
# need to work back to the last medication event, and pull out the food events in between
end

# maybe pull all the fields and be selective when printing the object
c = collection.find(query, {:sort => ['timestamp', 'ascending'], :fields => ['date', 'time', 'type', 'value', 'tag', 'notes']})
c.each do |d|
  e = Event.new d
  puts e
  puts 
end

