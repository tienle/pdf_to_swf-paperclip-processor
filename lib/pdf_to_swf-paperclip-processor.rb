require "paperclip"
module Paperclip
    class PdfToSwf < Processor

    attr_accessor :file, :params, :format

    def initialize file, options = {}, attachment = nil
      super
      @file           = file
      @params         = options[:params]
      @current_format = File.extname(@file.path)
      @basename       = File.basename(@file.path, @current_format)
      @format         = options[:format]
    end

    def make
      src = @file
      dst = Tempfile.new([@basename, @format ? ".#{@format}" : ''])
      begin
        parameters = []
        parameters << @params
        parameters << ":source"
        parameters << ":dest"

        parameters = parameters.flatten.compact.join(" ").strip.squeeze(" ")

        src_path = File.expand_path(src.path)
        dst_path = File.expand_path(dst.path)
        success = Paperclip.run("pdf2swf", parameters, :source => src_path, :dest => dst_path)

        # This pdf has been protected,
        # we need to unprotect it before converting to swf.
        if success =~ /FATAL.+disallows/i
          postscript      = Tempfile.new([@basename, '.ps'])
          unprotected_src = Tempfile.new([@basename, 'unprotected', '.pdf'])
          ps_params       = ":source :dest"

          Paperclip.run("pdf2ps", ps_params, :source => src_path, :dest => File.expand_path(postscript.path))
          src_path = File.expand_path(unprotected_src.path)
          Paperclip.run("ps2pdf", ps_params, :source => File.expand_path(postscript.path), :dest => src_path)
          success = Paperclip.run("pdf2swf", parameters, :source => src_path, :dest => dst_path)
        end
      rescue Cocaine::CommandLineError => e
        begin
          Paperclip.run("pdf2swf", parameters + " -s poly2bitmap", :source => src_path, :dest => dst_path)
        rescue
          raise PaperclipError, "There was an error converting #{@basename} to swf"
        end
      end
      dst
    end

  end
end
