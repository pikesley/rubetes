#!/usr/bin/env ruby

require 'tzinfo'
require 'mongo'
require 'optparse'

class Event < Hash
  def initialize hash
    self.update hash
  end

  def to_s
    s = ""
    keys = [
      "day",
      "date",
      "time",
      "type",
      "value",
      "units",
      "tag",
      "notes"
    ]
    keys.each do |k|
      if self[k] then
        s << "%010s: " % k
        s << self[k].to_s
        s << "\n"
      end
    end

    s
  end
end

class Glucose < Event
  def initialize hash
    super hash

    self["units"] = "mmol/L"

    if self["value"] < 4.0 then
      self["crash"] = true
    end

    if self["tag"] == "Crash"
      self["crash"] = true
    end
  end

  def get_crash
    i = self["timestamp"].to_i - self["last_meds"]["timestamp"].to_i
    interval = Time.at(i).gmtime.strftime('%H hours %M minutes')

    s = "Crash"
    s << "\n"

    s << "%010s: " % "BG of"
    s << self["value"].to_s
    s << " "
    s << self["units"]
    s << "\n"

    s << "%010s: " % "at"
    s << self["time"]
    s << "\n"

    s << "%010s: " % "on"
    s << self["day"]
    s << " "
    s << self["date"]
    s << "\n"

    s << "%010s: " % "happened"
    s << interval.to_s
    s << "\n"

    s << "%010s: " % "after"
    s << self["last_meds"]["value"].to_s
    s << " "
    s << self["last_meds"]["units"]
    s << "\n"

    s << "%010s: " % "of"
    s << self["last_meds"]["subtype"]

    s
  end

  def to_s
    s = super.to_s

    if self["crash"] then
      s << "%010s: " % "crash"
      s << self["crash"].to_s
    end

    s
  end
end

class Medication < Event
  def initialize hash
    super hash

    self["units"] = "10^-5 L"
  end
end

class Weight < Event
  def initialize hash
    super hash

    self["units"] = "Kg"
  end
end

class Food < Event
  def initialize hash
    super hash

    self["units"] = "g"
  end
end

def event_factory hash
  return Kernel.const_get(hash["type"]).new hash
end

# OnTrack uses really shitty date formats
def fix_date d
  h = {}

  t = Time.parse d
  h["timestamp"] = t
  h["tzoffset"] = t.strftime "%z"
  h["timezone"] = t.zone
  h["unixtime"] = t.to_i
  h["day"] = t.strftime "%A"
  h["date"] = t.strftime "%F"
  h["time"] = t.strftime "%T #{h['timezone']}"

  h
end

options = {}
time_options = 0
optparse = OptionParser.new do |opts|
  opts.banner = "Usage: rubetes.rb [options] [csv_file]"

  options[:crash] = false
  opts.on('-c', '--crash', 'Report on BG crashes') do
    options[:crash] = true
  end

# specify output file?
  options[:csv] = false
  opts.on('-s', '--csv', 'Generate CSV output') do
    options[:csv] = true
  end

  options[:type] = nil
  opts.on('-t', '--type TYPE', 'Show only TYPE data') do |t|
    options[:type] = t.split(/(\W)/).map(&:capitalize).join
  end

  options[:tag] = nil
  opts.on('--tag TAG', 'Show only TAG data') do |tag|
    options[:tag] = tag.split(/(\W)/).map(&:capitalize).join
  end

  options[:week] = false
  opts.on('-w', '--week', 'Show last 7 days') do
    options[:week] = true
    time_options += 1
  end

  options[:go_back_days] = nil
  opts.on('-g', '--go-back-days N', 'Go back N days') do |n|
    options[:go_back_days] = n
    time_options += 1
  end

  options[:for_date] = nil
  opts.on('-d', '--date DATE', 'Show date DATE') do |d|
    options[:for_date] = fix_date(d)["date"]
    time_options += 1
  end

  opts.on( '-h', '--help', 'Display this screen' ) do
    puts opts
    exit
  end
end

optparse.parse!

if time_options > 1 then
  puts "-g, -d and -w are mutually exclusive"
  exit
end

connection = Mongo::Connection.new
db = connection.db("rubetes")
collection = db.collection("events")

if ARGV[0] then
  file = File.new(ARGV[0], "r")
  while (line = file.gets)
    bits = line.split ","

    h = {}
    h["serial"] = bits[0].to_i #"%05d" % bits[0].to_i
    h.update fix_date "#{bits[1]}#{bits[2]}"
    h["type"] = bits[3]
    h["subtype"] = bits[4] if not bits[4] == ""
    h["tag"] = bits[5] if not bits[5] == ""
    h["value"] = bits[6].to_f
  
    notes = bits[7][1..-3]
    h["notes"] = notes if not notes == ""
    e = event_factory h

    collection.update({"serial" => e["serial"]}, e, {:upsert => true})
  end
  file.close
end

query = {}
if options[:for_date] then
  query[:date] = options[:for_date]
end

if options[:go_back_days] then
  target_date =
    (Time.now - (86400 * options[:go_back_days].to_i)).strftime "%F"
  query[:date] = {"$gt" => "#{target_date}"}
end

if options[:week] then
  target_date = (Time.now - (86400 * 7)).strftime "%F"
  query[:date] = {"$gt" => "#{target_date}"}
end

if options[:crash] then
  l = []
  c = collection.find(query, {:sort => ['timestamp', 'ascending']})
  c.each do |r|
    e = event_factory r
    l << e
  end

  last_meds = nil
  l.each do |e|
    if e.class.name == "Medication"
      last_meds = e
    end
    if e.class.name == "Glucose"
      e["last_meds"] = last_meds
    end
    if e["crash"] then
      puts e.get_crash
      puts
    end
  end

else
  if options[:type] then
    query[:type] = options[:type]
  end

  if options[:tag] then
    query[:tag] = options[:tag]
  end

  c = collection.find(query, {:sort => ['timestamp', 'ascending']})

  c.each do |d|
    e = event_factory d
    puts e
    puts
  end
end
