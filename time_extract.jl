#=
    2019.3.20
    wechat:  Cyvadra
    mail:    dj@lifesdk.com
    License: Apache 2.0
    版权所有: 上海禀土科技发展有限公司

=#

using Dates
using SoftGlobalScope


function generate_date(t_patch::Dict{} = time_patch)
    Dates.DateTime( t_patch["year"],t_patch["month"],t_patch["day"],t_patch["hour"],t_patch["minute"] )
end

function time_standardization(t_patch::Dict{})
    while t_patch["minute"] >= 60
        t_patch["hour"]   += 1
        t_patch["minute"] -= 60
    end
    while t_patch["hour"] >= 24
        t_patch["day"]  += 1
        t_patch["hour"] -= 24
    end
    @softscope while t_patch["day"] > Dates.day( Dates.lastdayofmonth( Dates.Date(t_patch["year"],t_patch["month"],1) ) )
        t_patch["day"]   -= Dates.day( Dates.lastdayofmonth( Dates.Date(t_patch["year"],t_patch["month"],1) ) )
        t_patch["month"] += 1
    end
    t_patch
end

function _into_num(pure_number_pattern)
    try
        if string( parse(Int,pure_number_pattern) ) == string(pure_number_pattern)
            return parse(Int64,pure_number_pattern)
        end
    catch
        tmp_first, tmp_sum = 1, 0
        d_nums  = Dict( '半' => 0.5, '零' => 0,  '一' => 1,  '二' => 2, '两' => 2, '三' => 3,  '四' => 4, '五' => 5,  '六' => 6, '七' => 7,  '八' => 8, '九' => 9,'0' => 0,  '1' => 1,'2' => 2,'3' => 3, '4' => 4,'5' => 5,'6' => 6, '7' => 7,'8' => 8, '9' => 9 )
        d_units = Dict( '个' => 1, '十' => 10, '百' => 100 )
        for char in pure_number_pattern
            if haskey(d_units,char)
                tmp_sum += d_units[char]*tmp_first
                tmp_first= 0
            end
            if haskey(d_nums,char)
                tmp_first = d_nums[char]
            end
        end
        if tmp_first !== 0
            tmp_sum += tmp_first
        end
        return tmp_sum
    end
end

function calc_target_time(input_time_string="明天八点半叫我起床")
    
    # data patch
        current_time       = now()
        time_patch         = Dict(  "year" => Dates.year(current_time),
                                    "month"=> Dates.month(current_time),
                                    "day"  => Dates.day(current_time),
                                    "hour" => Dates.hour(current_time),
                                    "minute"=>Dates.minute(current_time)
                                )
        current_time       = generate_date(time_patch)
        default_hour       = 12
        default_morning    = 9
        default_afternoon  = 14
        default_evening    = 19

    # correction
        input_time_string  = replace(input_time_string,r"([早晚天])+儿" => s"\g<0>")
        input_time_string  = replace(input_time_string,"明早" => "明天早上")
        input_time_string  = replace(input_time_string,"明晚" => "明天晚上")
        input_time_string  = replace(input_time_string,"今晚" => "今天晚上")

    # month & date
        pattern_next_month = r"(下[个]?月)+([0-9一二三]?十?[0-9一二三四五六七八九]?[号日])+"
            if match(pattern_next_month,input_time_string) !== nothing
                time_patch["month"] += 1
                time_patch["day"]    = 1
                time_patch["hour"] = default_hour; time_patch["minute"] = 0; 
            end
        pattern_month      = r"(([0-9一二三四五六七八九十]+[一二]?)月)?([0-9一二三]?十?[0-9一二三四五六七八九十]+)[号日]+"
            if match(pattern_month,input_time_string) !== nothing
                tmp_month = match(pattern_month,input_time_string)[2]
                tmp_day   = match(pattern_month,input_time_string)[4]
                tmp_month !== nothing ? time_patch["month"] = _into_num(tmp_month) : false
                tmp_day   !== nothing ? time_patch["day"]  = _into_num(tmp_day)    : false
                time_patch["hour"] = default_hour; time_patch["minute"] = 0;
            end

    # week
        pattern_next_week  = r"下个?[周礼拜星期]+"
            if match(pattern_next_week,input_time_string) !== nothing
                @softscope while Dates.week( Dates.Date(time_patch["year"],time_patch["month"],time_patch["day"]) ) == Dates.week(Dates.Date(current_time)) # should == current+1
                    time_patch["day"] += 1
                    time_patch = time_standardization(time_patch)
                end
            end
        pattern_week       = r"[周礼拜星期]+([一二三四五六天日])+"
            if match(pattern_week,input_time_string) !== nothing
                tmp_weekday = match(pattern_week,input_time_string)[1]
                weekday_list= Dict( "一"=>Dates.ismonday,"二"=>Dates.istuesday,"三"=>Dates.iswednesday,"四"=>Dates.isthursday,"五"=>Dates.isfriday,"六"=>Dates.issaturday,"天"=>Dates.issunday,"日"=>Dates.issunday )
                @softscope while weekday_list[tmp_weekday]( Dates.Date(time_patch["year"],time_patch["month"],time_patch["day"]) ) == false
                    time_patch["day"] += 1
                    time_patch = time_standardization(time_patch)
                end
                time_patch["hour"] = default_hour; time_patch["minute"] = 0;
            end

    # day afterwards
        if match(r"[明后]天",input_time_string) !== nothing
            occursin("明天",input_time_string)   ? time_patch["day"] += 1 : false
            occursin("后天",input_time_string)   ? time_patch["day"] += 2 : false
            occursin("大后天",input_time_string) ? time_patch["day"] += 1 : false # extra
            time_patch["hour"] = default_hour; time_patch["minute"] = 0;
        end
        pattern_day_later  = r"([0-9零一二三四五六七八九十]?[0-9零一二三四五六七八九十]?)+[天日]+后"
            if match(pattern_day_later,input_time_string) !== nothing
                time_patch["day"] += _into_num( match(pattern_day_later,input_time_string)[1] )
                time_patch = time_standardization(time_patch)
            end

    # hour
        pattern_next_hour  = r"([0-9一二三四五六七八九十]个?半?)小时后"
            if match(pattern_next_hour,input_time_string) !== nothing
                time_patch["minute"] += _into_num( match(pattern_next_hour,input_time_string)[1] )*60
                #time_standardization()
            end
        pattern_hour       = r"([0-9零一二三四五六七八九十]+)点钟?"
            if match(r"中午",input_time_string) !== nothing
                time_patch["hour"] = 12
            end
        pattern_morning    = r"(早上|上午|白天|凌晨)+"
        pattern_afternoon  = r"(下午|晚上|夜里)+"
            if match(pattern_morning,input_time_string) !== nothing
                time_patch["hour"]   = default_morning
                time_patch["minute"] = 0;
            elseif match(r"(下午)+",input_time_string) !== nothing
                time_patch["hour"]   = default_afternoon
                time_patch["minute"] = 0;
            elseif match(r"(晚上|夜里)+",input_time_string) !== nothing
                time_patch["hour"]   = default_evening
                time_patch["minute"] = 0;
            end
        if match(pattern_hour,input_time_string) !== nothing
            if match(pattern_morning,input_time_string) !== nothing
                tmp_hour   = _into_num( match(pattern_hour,input_time_string)[1] )
            elseif match(pattern_afternoon,input_time_string) !== nothing
                tmp_hour   = _into_num( match(pattern_hour,input_time_string)[1] ) + 12
                tmp_hour >= 24 ? tmp_hour -= 12 : tmp_hour
            else
                tmp_hour   = _into_num( match(pattern_hour,input_time_string)[1] )
            end
            time_patch["hour"]   = tmp_hour
            time_patch["minute"] = 0;
            time_patch           = time_standardization(time_patch)
        end

    # minute
        pattern_hour_half = r"点半"
            if match(pattern_hour_half,input_time_string) !== nothing
                time_patch["minute"] = 30
            end
        pattern_quarter   = r"([1-3一二三])刻钟?^后"
            if match(pattern_quarter,input_time_string) !== nothing
                time_patch["minute"] = _into_num( match(pattern_quarter,input_time_string) )*15
            end
        pattern_minute    = r"[0-9零一二三四五六七八九十]+点钟?([1-9一二三四五六七八九十]?[0-9一二三四五六七八九十]+)"
            if match(pattern_minute,input_time_string)  !== nothing
                time_patch["minute"] = _into_num( match(pattern_minute,input_time_string)[1] )
            end
        pattern_min_later = r"([0-9一二三四五六七八九十]+)分钟后"
            if match(pattern_min_later,input_time_string)  !== nothing
                time_patch["minute"] += _into_num( match(pattern_min_later,input_time_string)[1] )
            end

    # standardization
        target_time_patch = time_standardization( time_patch )
        target_time = generate_date(target_time_patch)

    if target_time == current_time
        return Dict( "hasTime"=>false,"DateTime"=>current_time )
    else
        return Dict( "hasTime"=>true, "DateTime"=>target_time  )
    end

end








