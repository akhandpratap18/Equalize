import json

def handler(event, context):
    packet = event.get("packet", [])
    packet.sort(key=lambda x: x.get("startTimeSec", 0))
    
    # Pre-process packet: split any massively long segments into smaller ~50-word mini-segments
    # so we can batch them properly.
    normalized_packet = []
    for item in packet:
        text = item.get("text", "")
        words = text.split()
        if len(words) > 100:
            # split into chunks of ~50 words
            chunk_size = 50
            for i in range(0, len(words), chunk_size):
                sub_text = " ".join(words[i:i+chunk_size])
                normalized_packet.append({
                    "text": sub_text,
                    "startTimeSec": item.get("startTimeSec", 0),
                    "endTimeSec": item.get("endTimeSec", 0),
                    "sourceType": item.get("sourceType", "SPOKEN")
                })
        else:
            normalized_packet.append(item)
            
    packet = normalized_packet
    
    # 2. Create small chunks for Embeddings (~150 words)
    chunks = []
    current_chunk_text = []
    current_start = -1
    current_end = -1
    current_type = "SPOKEN"
    
    def save_chunk():
        nonlocal current_chunk_text, current_start, current_end
        if current_chunk_text:
            text = " ".join(current_chunk_text)
            chunks.append({
                "text": text,
                "startTimeSec": current_start,
                "endTimeSec": current_end,
                "sourceType": current_type
            })
            current_chunk_text = []
            current_start = -1
            current_end = -1

    word_count = 0
    for item in packet:
        text = item.get("text", "")
        if not text.strip(): continue
        
        words = text.split()
        if current_start == -1:
            current_start = item.get("startTimeSec", 0)
        current_end = item.get("endTimeSec", 0)
        current_type = item.get("sourceType", "SPOKEN")
        
        current_chunk_text.append(text)
        word_count += len(words)
        
        if word_count >= 150:
            save_chunk()
            word_count = 0
    
    save_chunk()
    
    # 3. Create larger noteBatches (~1800 words)
    note_batches = []
    current_batch = []
    batch_word_count = 0
    
    for item in packet:
        text = item.get("text", "")
        words = text.split()
        
        current_batch.append(item)
        batch_word_count += len(words)
        
        if batch_word_count >= 1800:
            note_batches.append(current_batch)
            current_batch = []
            batch_word_count = 0
            
    if current_batch:
        note_batches.append(current_batch)
        
    event["chunks"] = chunks
    event["noteBatches"] = note_batches
    return event
