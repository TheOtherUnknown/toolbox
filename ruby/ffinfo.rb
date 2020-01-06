#!/usr/bin/env ruby
# frozen_string_literal: true

require 'json'
require 'time'
def grabline(file, num)
  File.foreach(file).with_index do |line, linen|
    return line.chomp if num == linen + 1
  end
end

def gettitle(file)
  grabline(file, 4)
end

def getauthor(file)
  l = grabline(file, 6)
  l[3, l.length]
end

def getrating(file)
  l = grabline(file, 18)
  l[8, l.length]
end

def getupdate(file)
  l = grabline(file, 16)
  Time.parse(l[9, l.length] + 'UTC')
end

def getpub(file)
  l = grabline(file, 17)
  Time.parse(l[10, l.length] + 'UTC')
end

def iscomplete?(file)
  l = grabline(file, 14)
  l = l[7, l.length]
  true unless l == 'In-Progress'
  false
end

def geturl(file)
  l = grabline(file, 22)
  l[11, l.length]
end

def getdesc(_file)
  yield
end

def parsefile(path)
  { 'Title' => gettitle(path), 'Author' => getauthor(path), 'Rating' => getrating(path), 'Last update' => getupdate(path), 'Published' => getpub(path), 'Complete' => iscomplete?(path), 'URL' => geturl(path) }.to_json
end
