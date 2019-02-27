require 'uri'
module QcloudCos
  class ObjectManager
    attr_accessor :bucket, :region, :access_id, :access_key, :http, :token
    def initialize(bucket: nil, region: nil, access_id: nil, access_key: nil, token: nil)
      @bucket = bucket
      @region = region
      @access_id = access_id
      @access_key = access_key
      @token = token
      @http = QcloudCos::Http.new(access_id, access_key, token: token)
    end

    def put_object(path, file, headers = {})
      http.put(compute_url(path), file.read, headers)
    end

    def copy_object(path, copy_source)
      body = http.put(compute_url(path), nil, 'x-cos-copy-source' => copy_source).body
      ActiveSupport::HashWithIndifferentAccess.new(ActiveSupport::XmlMini.parse(body))
    end

    def delete_object(path)
      http.delete(compute_url(path))
    end

    def compute_url(path)
      URI.join("https://#{bucket}.cos.#{region}.myqcloud.com", path).to_s
    end
  end
end
