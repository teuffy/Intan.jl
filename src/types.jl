
export SaveWave,SaveAll,SaveNone, FPGA

abstract RHD2000
abstract Task
abstract SaveOpt

global num_rhd = 0

type Debug
    state::Bool
    m::ASCIIString
    data::Array{Float64,1}
    ind::Int64
    maxind::Int64
end

type SaveWave <: SaveOpt 
end

type SaveAll <: SaveOpt
    v::ASCIIString
    ts::ASCIIString
    adc::ASCIIString
    ttl::ASCIIString
    folder::ASCIIString
end

function SaveAll()
    t=string("./",now())
    SaveAll(string(t,"/v.bin"),string(t,"/ts.bin"),string(t,"/adc.bin"),string(t,"/ttl.bin"),t)
end

type SaveNone <: SaveOpt
    ts::ASCIIString
    adc::ASCIIString
    ttl::ASCIIString
    folder::ASCIIString
end

function SaveNone()
    t=string("./",now())
    SaveNone(string(t,"/ts.bin"),string(t,"/adc.bin"),string(t,"/ttl.bin"),t)
end

type FPGA
    id::Int64
    shift::Int64
    board::Ptr{Void}
    sampleRate::Int64
    numDataStreams::Int64
    dataStreamEnabled::Array{Int64,2}
    usbBuffer::Array{UInt8,1}
    numWords::Int64
    numBytesPerBlock::Int64
    amps::Array{Int64,1}
    time::Array{UInt32,1}
    adc::Array{UInt16,2}
    ttlin::Array{UInt16,1}
    ttlout::Array{UInt16,1}
end

function FPGA(board_id::Int64,amps::Array{Int64,1})
    if board_id==1
        FPGA(1,0,board,30000,0,zeros(Int64,1,MAX_NUM_DATA_STREAMS),zeros(UInt8,USB_BUFFER_SIZE),0,0,amps,zeros(UInt32,SAMPLES_PER_DATA_BLOCK),zeros(UInt16,SAMPLES_PER_DATA_BLOCK,8),zeros(UInt16,SAMPLES_PER_DATA_BLOCK),zeros(UInt16,SAMPLES_PER_DATA_BLOCK))
    elseif board_id==2
        FPGA(2,0,board2,30000,0,zeros(Int64,1,MAX_NUM_DATA_STREAMS),zeros(UInt8,USB_BUFFER_SIZE),0,0,amps,zeros(UInt32,SAMPLES_PER_DATA_BLOCK),zeros(UInt16,SAMPLES_PER_DATA_BLOCK,8),zeros(UInt16,SAMPLES_PER_DATA_BLOCK),zeros(UInt16,SAMPLES_PER_DATA_BLOCK))
    end
end

function gen_rhd(v,prev,s,buf,nums,tas,sav,filts)

    global num_rhd::Int64
    num_rhd+=1
    k=num_rhd
    
    @eval begin
        type $(symbol("RHD200$k")) <: RHD2000
            fpga::Array{FPGA,1}
            v::$(typeof(v))
            prev::$(typeof(prev))
            s::$(typeof(s))
            buf::$(typeof(buf))
            nums::$(typeof(nums))
            debug::Debug
            reads::Int64
            cal::Int64
            task::$(typeof(tas))
            save::$(typeof(sav))
            filts::$(typeof(filts))
            sr::Int64
        end

        function make_rhd(fpga::Array{FPGA,1},v::$(typeof(v)),prev::$(typeof(prev)),s::$(typeof(s)),buf::$(typeof(buf)),nums::$(typeof(nums)),debug::Debug,tas::$(typeof(tas)),sav::$(typeof(sav)),filts::$(typeof(filts)))
            
            $(symbol("RHD200$k"))(fpga,v,prev,s,buf,nums,debug,0,0,tas,sav,filts,30000)
        end
    end
end

default_sort=Algorithm[DetectNeg(),ClusterWindow(),AlignMin(),FeatureTime(),ReductionNone(),ThresholdMeanN()]

debug_sort=Algorithm[DetectNeg(),ClusterWindow(),AlignMin(),FeatureTime(),ReductionNone(),ThresholdMeanN()]

default_debug=Debug(false,"off",zeros(Float64,1),0,0)

default_save=SaveAll()

function makeRHD(fpga::Array{FPGA,1},mytask::Task; params=default_sort, parallel=false, debug=default_debug,sav=default_sav,sr=30000,wave_time=1.6)

    c_per_fpga=[length(fpga[i].amps)*32 for i=1:length(fpga)]

    if length(c_per_fpga)>1
        for i=2:length(c_per_fpga)
            fpga[i].shift=c_per_fpga[i-1]
        end
    end
    
    numchannels=sum(c_per_fpga)
                  
    if debug.state==true
        params=debug_sort
    end

    notches=[make_notch(59,61,sr) for i=1:numchannels]

    wave_points=get_wavelength(sr,wave_time)
    
    if parallel==false
        v=zeros(Int16,SAMPLES_PER_DATA_BLOCK,numchannels)
        prev=zeros(Float64,SAMPLES_PER_DATA_BLOCK)
        s=create_multi(params...,numchannels,wave_points)
        (buf,nums)=output_buffer(numchannels)      
    else
        v=convert(SharedArray{Int16,2},zeros(Int64,SAMPLES_PER_DATA_BLOCK,numchannels))
        prev=convert(SharedArray{Float64,1},zeros(Int64,SAMPLES_PER_DATA_BLOCK))
        s=create_multi(params...,numchannels,1:1,wave_points)
        (buf,nums)=output_buffer(numchannels,true)       
    end
    gen_rhd(v,prev,s,buf,nums,mytask,sav,notches)
    rhd=make_rhd(fpga,v,prev,s,buf,nums,debug,mytask,sav,notches)

    rhd.sr=sr

    rhd
end

function make_notch(wn1,wn2,sr)
    responsetype = Bandstop(wn1,wn2; fs=sr)
    designmethod = Butterworth(4)
    df1=digitalfilter(responsetype, designmethod)
    DF2TFilter(df1)
end

get_wavelength(sr,timewin)=round(Int,sr*timewin/1000)

type mytime
    h::Int8
    h_l::Gtk.GtkLabelLeaf
    m::Int8
    m_l::Gtk.GtkLabelLeaf
    s::Int8
    s_l::Gtk.GtkLabelLeaf
end
    
type Gui_Handles
    win::Gtk.GtkWindowLeaf
    run::Gtk.GtkToggleButtonLeaf
    init::Gtk.GtkButtonLeaf
    cal::Gtk.GtkCheckButtonLeaf
    slider::Gtk.GtkScaleLeaf
    adj::Gtk.GtkAdjustmentLeaf
    slider2::Gtk.GtkScaleLeaf
    adj2::Gtk.GtkAdjustmentLeaf
    c::Gtk.GtkCanvasLeaf
    c2::Gtk.GtkCanvasLeaf
    spike::Int64 #currently selected spike out of total
    num::Int64 #currently selected spike out of 16
    num16::Int64 #currently selected 16 channels
    scale::Array{Float64,2}
    offset::Array{Float64,2}
    mi::NTuple{2,Float64} #saved x,y position of mouse input
    mim::NTuple{2,Float64} #saved x,y position of mouse input on multi-channel display
    var1::Array{Int64,2} #saved variable 1 for each channel
    var2::Array{Int64,2} #saved variable 2 for each channel
    sb::Gtk.GtkSpinButtonLeaf
    tb1::Gtk.GtkLabelLeaf
    tb2::Gtk.GtkLabelLeaf
    gain::Gtk.GtkCheckButtonLeaf
    gainbox::Gtk.GtkSpinButtonLeaf
    draws::Int64 #how many displays have occured since the last refresh
    thres_all::Gtk.GtkCheckButtonLeaf
    events::Array{Int64,1}
    enabled::Array{Bool,1}
    show_thres::Bool
    time::mytime
    wave_points::Int64
    c_right_top::UInt8 #flag to indicate the drawing method to be displayed on top part of right display
    c_right_bottom::UInt8 #flag to indicate the drawing method to be displayed on the bottom part of right display
    popup_ed::Gtk.GtkMenuLeaf
    popup_event::Gtk.GtkMenuLeaf
    rb1::Array{Gtk.GtkRadioButton,1}
    rb2::Array{Gtk.GtkRadioButton,1}
end

#=
C_Right Top Flags

1 = 16 channel
2 = 32 channels
3 = 64 channels
4 = 64 channels raster
5 = blank

C_Right Bottom Flags

1 = events/analog
2 = 16 channel raster
3 = 32 channel raster
4 = soft scope
5 = 64 channel
6 = 64 channel raster
7 = blank

=#
