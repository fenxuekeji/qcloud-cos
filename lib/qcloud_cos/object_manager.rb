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

    def put_object(path, file_or_bin, headers = {})
      data = file_or_bin.respond_to?(:read) ? IO.binread(file_or_bin) : file_or_bin
      http.put(compute_url(path), data, headers)
    end

    def copy_object(path, copy_source)
      body = http.put(compute_url(path), nil, 'x-cos-copy-source' => copy_source).body
      ActiveSupport::HashWithIndifferentAccess.new(ActiveSupport::XmlMini.parse(body))
    end

    def get_object(path, headers = {})
      response = http.get(compute_url(path), headers)
    end

    def get_object_url(path, headers = {})
      http.object_url_with_auth(compute_url(path), headers)
    end

    def head_object(path, headers = {})
      response = http.head(compute_url(path), headers)
    end

    # Tier 取回模式
    # Expedited：快速取回模式，恢复任务在1 - 5分钟内可完成。
    # Standard：标准取回模式，恢复任务在3 - 5小时内完成 
    # Bulk：批量取回模式，恢复任务在5 - 12小时内完成。
    # 对于恢复深度归档存储类型数据，有两种恢复模式，分别为：
    # Standard：标准取回模式，恢复时间为12 - 24小时。
    # Bulk：批量取回模式，恢复时间为24 - 48小时。
    def restore_object(path, tier='Standard', days=30)
      
      data="<RestoreRequest>
              <Days>#{days}</Days>
              <CASJobParameters>
                <Tier>#{tier}</Tier>
              </CASJobParameters>
            </RestoreRequest>"
      headers = {
        # 'Content-Length': data.length.to_s,
        'Content-Type': 'application/xml',
        'Content-MD5': Base64.strict_encode64(Digest::MD5.digest data),
        'Host': compute_host,
      }
      response = http.post(compute_url(path+"?restore"), data, headers)
      case response.code
      when '202'
        res_hash = response.to_hash
        return {
          status: 'success',
          cos_request_id: res_hash["x-cos-request-id"],
        }
      when '200'
        res_hash = response.to_hash
        return {
          status: 'success',
          cos_request_id: res_hash["x-cos-request-id"],
        }
      when '409'
        body_hash = ActiveSupport::HashWithIndifferentAccess.new(ActiveSupport::XmlMini.parse(response.body))
        return {
          status: 'success',
          cos_code: body_hash['Error']['Code']["__content__"],
          cos_request_id: body_hash['Error']['RequestId']["__content__"],
        }
      when '404'
        body_hash = ActiveSupport::HashWithIndifferentAccess.new(ActiveSupport::XmlMini.parse(response.body))

        return {
          status: 'fail',
          cos_code: body_hash['Error']['Code']["__content__"],
          cos_request_id: body_hash['Error']['RequestId']["__content__"],
        }
      else
        return {
          status: 'unknown',
          http_code: response.code,
          cos_msg: response.as_json,
        }
      end
    end

    def delete_object(path)
      http.delete(compute_url(path))
    end

    def compute_url(path)
      URI.join("https://#{compute_host}", path).to_s
    end

    def compute_host
      "#{bucket}.cos.#{region}.myqcloud.com"
    end
  end
end
