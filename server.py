import os
import requests
import yt_dlp
from flask import Flask, jsonify, request, Response

NODE_PATH = '/opt/homebrew/bin/node' 
os.environ["PATH"] += os.pathsep + os.path.dirname(NODE_PATH)

app = Flask(__name__)

STREAM_CACHE = {}

@app.route('/search')
def search():
    query = request.args.get('q')
    if not query: return jsonify([])
    url = f"https://itunes.apple.com/search?term={query}&entity=song&limit=15"
    try:
        r = requests.get(url)
        return jsonify([{"title": i.get('trackName'), "artist": i.get('artistName'), 
                         "cover": i.get('artworkUrl100'), "id": f"{i.get('artistName')} {i.get('trackName')}"} 
                        for i in r.json().get('results', [])])
    except: return jsonify([])

@app.route('/track')
def get_track():
    search_str = request.args.get('id')
    print(f"--- Поиск аудио для: {search_str} ---")
    
    ydl_opts = {
        'format': '18/best[ext=mp4]',
        'noplaylist': True,
        'quiet': True,
        'no_warnings': True,
        'javascript_executable': NODE_PATH,
        'nocheckcertificate': True,
    }
    try:
        with yt_dlp.YoutubeDL(ydl_opts) as ydl:
            info = ydl.extract_info(f"ytsearch1:{search_str}", download=False)
            entry = info['entries'][0]
            video_id = entry['id']
            
            STREAM_CACHE[video_id] = {
                'url': entry['url'],
                'headers': entry.get('http_headers', {})
            }
            
            proxy_url = f"http://{request.host}/proxy?vid={video_id}"
            print(f"!!! Ссылка готова: {proxy_url}")
            return jsonify({"stream_url": proxy_url})
    except Exception as e:
        print(f"!!! Ошибка yt-dlp: {e}")
        return jsonify({"error": str(e)}), 500

@app.route('/proxy')
def proxy():
    vid = request.args.get('vid')
    
    if vid not in STREAM_CACHE:
        return "Not found", 404
        
    stream_info = STREAM_CACHE[vid]
    url = stream_info['url']
    headers = stream_info['headers'].copy() 
    
    range_header = request.headers.get('Range')
    if range_header:
        headers['Range'] = range_header

    print(f"--- Проксирую поток (Без чанков!): {vid} (Range: {range_header}) ---")
    r = requests.get(url, headers=headers, timeout=15)
    
    response_headers = {
        'Content-Type': r.headers.get('Content-Type', 'audio/mp4'),
        'Accept-Ranges': 'bytes'
    }
    if 'Content-Length' in r.headers:
        response_headers['Content-Length'] = r.headers['Content-Length']
    if 'Content-Range' in r.headers:
        response_headers['Content-Range'] = r.headers['Content-Range']
    return Response(r.content, status=r.status_code, headers=response_headers)

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=8080)
