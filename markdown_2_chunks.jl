#=
  Usage:
    include this file
    ProcessFile(filename, if_include_filename_as_title, if_disable_manual_doublecheck)
    ::Vector{String} # as blocks
=#

MIN_CHUNK_LENGTH = 40
MAX_CHUNK_LENGTH = 1500
ACCEPTABLE_TITLE_LENGTH = 64
flagModeQuiet = false
flagUseFileName = true

cacheChars = Char[];
uniqueChars = Char[];
function regularSplit(str::AbstractString)::Vector{String}
  ret = String[]
  global cacheChars, uniqueChars, MAX_CHUNK_LENGTH
  s = [c for c in str]
  while length(s) > MAX_CHUNK_LENGTH
    cacheChars = s[1:MAX_CHUNK_LENGTH]
    uniqueChars = unique(cacheChars)
    n = 0
    for endChar in ['\n', ' ', '。', '；', '”', '：', '？', '》']
      if endChar in uniqueChars
        for i in MAX_CHUNK_LENGTH:-1:1
          if cacheChars[i] == endChar
            n = i
            break
          end
        end
      end
      if n > 0
        break
      end
    end
    push!(ret, join(s[1:n]))
    s = s[n+1:end]
    end
  if 0 < length(s)
    push!(ret, join(s))
  end
  empty!(cacheChars)
  empty!(uniqueChars)
  return ret
  end

function joinIfNotEmpty(v::Vector, delim)
  v = filter(x->length(x)>0,v)
  if length(v) < 2
    if length(v) == 0
      return ""
    end
    return v[1]
  end
  return join(v,delim)
  end
function fname2title(fname::String)
  fname = replace(fname, r"\.?/.*/"=>"")
  if fname[1] in '0':'9'
    fname = replace(fname, r"[0-9]+_"=>"")
    end
  fname = replace(fname, r"附件[:：]* ?"=>"")
  fname = replace(fname, ".md"=>"")
  fname = replace(fname, ".txt"=>"")
  fname = replace(fname, r"\s+"=>"")
  return fname
  end

function ProcessFile(fname::String)::Vector{String}
  @info "Processing file $fname..."
  # runtime vars
  ret = String[]
  globalTitle = flagUseFileName ? fname2title(fname) : ""
  levelTitles = []
  currentLevel = 0
  prevLevel = 0
  # read file
  s = "\n"*read(fname,String)*"\n";
  s = replace(s, "\n#" => "\n\n#")
  # process content
  titles_match = collect(eachmatch(r"\n(#+)\s*(\S+.*)\n\s*?", s))
  sort!(titles_match,by=x->x.offset)
  levels = map(t->length(t.captures[1]),titles_match)
  start_positions = map(t->t.offset, titles_match)
  # handle empty title
  if isempty(start_positions)
    append!(ret, map(x->joinIfNotEmpty([globalTitle, x], " "), regularSplit(s)))
    return ret
  end
  titles_range = map(t-> t.offsets[2] : t.offsets[2]+lastindex(t.captures[2])-1 ,titles_match)
  # if there's content before title, ask user how to process
  if start_positions[1] > 1
    tmpStr = s[1:prevind(s,start_positions[1])]
    tmpStr = replace(tmpStr, r"\n+"=>"")
    tmpStr = replace(tmpStr, r"\s*\!\[.*\]\(\S+\)\s*"=>"")
    if flagModeQuiet
      if length(tmpStr) > ACCEPTABLE_TITLE_LENGTH
        append!(ret, map(x->joinIfNotEmpty([globalTitle, x], " "), regularSplit(tmpStr)))
      elseif length(tmpStr) > 0
        globalTitle = joinIfNotEmpty([globalTitle, tmpStr], " ")
      end
    elseif length(tmpStr) > MIN_CHUNK_LENGTH && tmpStr != globalTitle
      @warn "Save following text as global title? (y/n/discard)"
      println(tmpStr)
      replyStr = lowercase(readline())
      if occursin("y", replyStr)
        globalTitle = joinIfNotEmpty([globalTitle, tmpStr], " ")
        @info "global title saved"
      elseif occursin("d", replyStr)
        nothing
      else
        append!(ret, map(x->joinIfNotEmpty([globalTitle, x], " "), regularSplit(tmpStr)))
      end
    end
  end
  globalTitle = replace(globalTitle, r"\n+"=>"")
  length(globalTitle) > 0 ? push!(levelTitles, globalTitle) : nothing
  # start iteration from titles
  for i in eachindex(titles_range)
    # judge title level
    currentLevel = levels[i]
    currentTitle = replace(s[titles_range[i]],r"\s+"=>"")
    if currentLevel < prevLevel
      pop!(levelTitles)
    elseif currentLevel > prevLevel
      if isempty(levelTitles) || ( !isempty(levelTitles) && currentTitle != levelTitles[end] )
        push!(levelTitles, currentTitle)
      end
    else
      pop!(levelTitles)
      push!(levelTitles, currentTitle)
    end
    # fetch content
    startIndex = nextind(s,titles_range[i][end])+1
    endIndex = i < length(titles_range) ? prevind(s,titles_match[i+1].offset-1) : lastindex(s)
    tmpContent = replace(s[startIndex:endIndex], r"\n+"=>"\n")
    tmpTitle = join(levelTitles, "\n")
    if length(tmpContent) > MAX_CHUNK_LENGTH
      append!(ret, tmpTitle .* regularSplit(tmpContent))
    elseif length( replace(tmpContent, r"\s"=>"") ) > MIN_CHUNK_LENGTH
      push!(ret, tmpTitle * tmpContent)
    end
    prevLevel = currentLevel
  end
  return ret
  end


# EOF