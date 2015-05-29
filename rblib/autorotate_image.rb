# -*- encoding : utf-8 -*-
# This is for rotating images to the right orientation based on the
# EXIF orientation data.  It depends on the binary jhead from the
# package jhead.

require 'open3'

# If there is no error, this returns nil.  If there was any error, a
# string with the error is returned (just the captured standard
# error):

def autorotate_image( filename )

  captured_stderr = nil

  Open3.popen3('jhead', '-autorot', filename) do |input, output, error|
    captured_stdout = output.read
    captured_stderr = error.read
  end

  if captured_stderr.strip.empty?
    return nil
  else
    return captured_stderr
  end

end
