require 'rest_client'
require 'addressable/uri'
require 'net/http'
require 'digest/sha1'
require 'json'

class Phaxio
  attr_reader :api_key
  attr_reader :api_secret

  def initialize(api_key=nil,api_secret=nil,host=nil)
    @debug = false
    @api_key = api_key
    @api_secret = api_secret
    if host!=nil
      @host = host
    else
      @host = "https://api.phaxio.com/v1/"
    end
  end

  def faxStatus(faxId)
    if !faxId
      raise PhaxioException, "You must include a fax id"
    end
    doRequest(@host+'faxStatus',{'id'=>faxId})
  end

  def sendFax(to,filenames = [], options = {})
    if !filenames.respond_to?("each")
      filenames = [filenames]
    end

    if to.nil? or to == 0
      raise PhaxioException, "You must include a 'to' number. "
    end

    if filenames.length == 0 and not options.has_key?'string_data'
      raise PhaxioException, "You must include a file to send. "
    end

    params = {}
    if to.respond_to?("each")
       to.each_index do |i|
         params["to[#{i}]"] = to[i]
       end
    else
      params['to[0]']=to
    end

    filenames.each_index do |i|
      if not File.exist?(filenames[i])
        raise PhaxioException, "The file '#{filenames[i]}' does not exist"
      end
      params["filename[#{i}]"] = File.new filenames[i]
    end

    paramsCopy(%w(string_data string_data_type batch batch_delay callback_url),options,params)
    doRequest(@host+'send',params)
  end

  def fireBatch(batchId)
    if !batchId
      raise PhaxioException, "You must provide a batch id"
    end
    doRequest(@host+'fireBatch',{'id'=>batchId})
  end
  
  def closeBatch(batchId)
    if !batchId
      raise PhaxioException, "You must provide a batch id"
    end
    doRequest(@host+'closeBatch',{'id'=>batchId})
  end

  def provisionNumber(areaCode,callbackURL=nil)
    if areaCode.nil? or areaCode == 0
      raise PhaxioException, "You must include an area code"
    end
    params = {"area_code"=>areaCode}
    if not callbackURL.nil?
      params["callback_url"] = callbackURL
    end
    doRequest(@host+'provisionNumber',params)
  end

  def releaseNumber(number)
    if not number or number == ""
      raise PhaxioException, "You must include an a fax number"
    end
    doRequest(@host+'releaseNumber',{"number"=>number})
  end

  def numberList(options = nil)
    params = {}
    if not options.nil?
      paramsCopy(%w(area_code number),options,params)
    end
    doRequest(@host+'numberList',params)
  end

  def accountStatus()
    doRequest(@host+'accountStatus',{})
  end

  def testReceive(filename,options=nil)
    if filename.nil? or filename == ""
      raise PhaxioException, "You must include a file name"
    elsif File.extname(filename) != '.pdf'
      raise PhaxioException, "You must include a pdf file"
    elsif not File.exists?(filename)
      raise PhaxioException, "File #{filename} does not exist"
    end
    params = {"filename"=>File.new(filename)}
    if not options.nil?
      paramsCopy(%w(from_number to_number),options,params)
    end
    doRequest(@host+'testReceive',params)
  end

  def attachPhaxCode(x,y,filename,options=nil)
    if x.nil? or y.nil?
      raise PhaxioException, "x and y coordinates are required"
    end
    if filename.nil? or filename == ""
      raise PhaxioException, "You must include a file name"
    elsif File.extname(filename) != '.pdf'
      raise PhaxioException, "You must include a pdf file"
    elsif not File.exists?(filename)
      raise PhaxioException, "File #{filename} does not exist"
    end
    params = {"filename"=>File.new(filename),"x"=>x,"y"=>y}
    if not options.nil?
      paramsCopy(%w(metadata page_number),options,params)
    end
    doRequest(@host+'attachPhaxCodeToPdf',params)
  end

  def createPhaxCode(options = nil)
    params = {}
    if not options.nil?
      paramsCopy(%w(metadata redirect),options,params)
    end
    doRequest(@host+'createPhaxCode',params)
  end

  def getHostedDocument(name,metaData=nil)
    if name.nil? or name == ""
      raise PhaxioException, "You must include a document name"
    end
    params = {"name"=>name}
    if not metaData.nil?
      params["metaData"] = metaData
    end
    doRequest(@host+'getHostedDocument',params)
  end

  def faxFile(id,type='p')
    if id.nil? or id==0
      raise PhaxioException, "A fax id is required"
    end
    params = {"id"=>id,"type"=>type}
    doRequest(@host+'faxFile',params)
  end

  def faxList(starttime,endtime,options=nil)
    if starttime.nil? or endtime.nil?
      raise PhaxioException, "Start time and end time are required"
    end
    params = {"start"=>starttime,"end"=>endtime}
    if not options.nil?
      paramsCopy(%w(page max_per_page),options,params)
    end
    doRequest(@host+'faxList',params)
  end

  private

  def paramsCopy(names,options,params)
    if options.respond_to? "has_key?"
      names.each do |name|
        if options.has_key? name
          params[name] = options[name]
        end
      end
    else
      raise PhaxioException, "Options must be a hash"
    end
  end

  def doRequest(address,params,wrapinphaxiooperationresult = false)
    params["api_key"] = @api_key
    params["api_secret"] = @api_secret
    if @debug
      uri = new Addressable::URI.new
      uri.query_values = params
      printf "\n\nRequest Address: \n\n#{address}?#{uri.query}\n\n"
    end
    result = sendData(address,params)
    if @debug
      print "Response: \n\n#{result}\n\n"
    end
    if wrapinphaxiooperationresult
      begin
        result = JSON.parse(result)
      rescue
        return PhaxioOperationResult.new(false,"No data received from service.")
      end
      success = nil
      message = nil
      data = nil
      if result.has_key? "success"
        success = result["success"]
      end
      if result.has_key? "message"
        message = result["message"]
      end
      if result.has_key? "data"
        data = result["data"]
      end
      return PhaxioOperationResult.new(success,message,data)
    end
    return result
  end

  def sendData(address,params)
    RestClient.post(address,params)
  end

end

class PhaxioException < StandardError
end

class PhaxioOperationResult
  attr_reader :success
  attr_reader :message
  attr_reader :data
  def initialize(success,message = nil,data = nil)
    @success = success
    @message = message
    @data = data
  end

end
