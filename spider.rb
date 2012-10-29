require 'rubygems'
require 'tumblr_client'
require 'uri'
require 'pp'


GIF_MAX_WIDTH  = 1024
GIF_MAX_HEIGHT = 768

Tumblr.configure do |config|
  config.consumer_key = "AcHYlG5GaS9xf842H1RC8WF81cvAH9zqf7fvxGSrfHQSy7ksqO"
  config.consumer_secret = "SYfZQUh6kGgEG3zAtQwO9jJwGEDcVXBMRg1QUTRIMZqBqDHMUR"
end

$tumblr = Tumblr.new

class IndexedGif
  def initializer
  end
  attr_accessor :gif_url, :source_url, :source_name, :source_id, :tags, :caption, :individual_caption

  def store
    @indexed_time = Time.now.getutc
    ## Make this serialize and store to database
    pp self
  end
end

class String
  def ends_with?(str)
    str = str.to_str
    tail = self[-str.length, str.length]
    tail == str
  end
end

def scour_account(baseurl)
  blog_info = $tumblr.blog_info(baseurl)
  post_count = blog_info['blog']['posts']
  puts post_count

  puts "Scouring account..."
  (0..post_count).step(20) do |offset|
    puts "Offset is #{offset}"
    $tumblr.posts(baseurl, type: :photo, offset: offset)['posts'].each do |post|
       process_post post
    end
  end

end


def process_post(post, force_no_source=false)

  unless (post.class == Hash and post['type'] == 'photo')
    return false
  end

  pp post

  force_no_source = true if post['source_url'] == post['post_url']

  if(post['source_url'] && !force_no_source)
    # This isn't the original source of this post! Go get it from there.
    uri = URI(post['source_url'])

    return process_post(post, true) if uri.path == "" or uri.path == "/" # Bail out on malformed source URLs! todo: image should still be indexed!

    baseurl = uri.host
    id = uri.path.split('/')[2].to_i


    data = $tumblr.posts(baseurl, limit: 1, id: id)
    return process_post(post, true) if data.empty? # Bail out if the source post either a/ doesn't exist any more or b/ was never a tumblr post


    process_post(data['posts'].first)

    scour_todo_add baseurl
  else
    # This is the original source of this post
    post['photos'].each do |photo|
      image = photo['original_size']

      unless image['url'].ends_with?(".gif")
        # Not a gif, discard
        next
      end

      if image['width'] > GIF_MAX_WIDTH or image['height'] > GIF_MAX_HEIGHT
        # Image too large, discard
        next
      end

      gif = IndexedGif.new
      gif.gif_url             = image['url']
      gif.source_url          = post['post_url']
      gif.source_name         = post['blog_name']
      gif.source_id           = post['id']
      gif.tags                = post['tags']
      gif.caption             = post['caption']
      gif.individual_caption  = photo['caption']

      gif.store
    end
  end
  return nil
end

def scour_todo_add(baseurl)
  #todo: Make this add to a todo list
  puts "Todo list appended with #{baseurl}"
end
scour_account "gaysexistheanswer.tumblr.com"