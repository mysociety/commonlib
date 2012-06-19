# This is essentially a Ruby version of the simple exifautotran script
# in libjpeg-progs.  It depends on the binaries:
#
#   jpegexiforient
#   jpegtran
#
# ... which can be found in libjpeg-progs (or libjpeg-turbo-progs)

require 'tempfile'

def safe_backticks( *command )
  Kernel.open( "|-", "r" ) do |f|
    if f
      return f.read
    else
      begin
        exec( *command )
      rescue
        raise "Couldn't exec #{command}: #{$!}\n"
      end
    end
  end
end

def autorotate_image( filename )

  # jpegexiforient returns blank output if the image is not a JPEG, or
  # there is no EXIF data relating to orientation, so this can be
  # safely applied to PNG images.

  transform = nil
  case safe_backticks('jpegexiforient', '-n', filename)
  when '2'
    transform = [ "-flip", "horizontal" ]
  when '3'
    transform = [ "-rotate", "180" ]
  when '4'
    transform = [ "-flip", "vertical" ]
  when '5'
    transform = [ "-transpose" ]
  when '6'
    transform = [ "-rotate", "90" ]
  when '7'
    transform = [ "-transverse" ]
  when '8'
    transform = [ "-rotate", "270" ]
  end

  if transform

    # Then the image should be rotated:

    temporary_file = Tempfile.new('fmt-image-')
    temporary_file.close()

    full_command = [ "jpegtran",
                     "-copy", "all",
                     "-outfile", temporary_file.path ]
    full_command += transform
    full_command += [ filename ]

    unless system(*full_command)
      raise "jpegtran invocation failed: #{full_command.join(' ')}"
    end

    # Now, update the EXIF information to say that no rotation is
    # required (any more).  (Use safe_backticks to capture and ignore
    # the standard output.)

    safe_backticks('jpegexiforient', '-1', temporary_file.path)

    File.rename(temporary_file.path, filename)

  end

end
