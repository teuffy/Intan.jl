#=
Plots detected spike on canvas for multiple channels
=#

draw_spike16(rhd::RHD2000,han::Gui_Handles)=draw_spike_n(rhd,han,4,4,16)

draw_spike32(rhd::RHD2000,han::Gui_Handles)=draw_spike_n(rhd,han,6,6,32)

draw_spike64(rhd::RHD2000,han::Gui_Handles)=draw_spike_n(rhd,han,6,11,64)

function draw_spike_n(rhd::RHD2000,han::Gui_Handles,n_col,n_row,num_chan)

    k_in=num_chan*(han.num16)-num_chan+1
    maxid=find_max_id(rhd,han,k_in,num_chan)
    ctx=getgc(han.c)
    xwidth=width(ctx)
    myheight=height(ctx)
    if num_chan<64
      yheight=myheight-300
    else
      yheight=myheight
    end

    scale(ctx,xwidth/(han.wave_points/2*n_col),1)

    #subsequent IDs
    @inbounds for thisid=1:maxid
	for chan=k_in:(k_in+num_chan-1)
	    if han.enabled[chan]
	        for g=1:rhd.nums[chan]
                    if (rhd.buf[g,chan].inds.start>0)&(rhd.buf[g,chan].inds.stop<size(rhd.v,1))
                        if rhd.buf[g,chan].id==thisid

                            #Gain and offset for channel
                            s=han.scale[chan,2]
                            o=han.offset[chan]

                            #x and y position for channel location
			    startx=div(rem(chan-1,num_chan),n_row)*han.wave_points/2+1
			    starty=yheight/n_row*(rem(rem(chan-1,num_chan),n_row))+yheight/n_row/2

                            #Max and min extents for line to stay within bounding box
                            ymax=starty+yheight/n_row/2
			    ymin=starty-yheight/n_row/2

                            y=(rhd.v[rhd.buf[g,chan].inds.start,chan]-o)*s+starty
			    
			    if (y<ymin)
                               y=ymin
                            elseif (y>ymax)
                               y=ymax
                            end
                            
                            move_to(ctx,startx,y)
                            for kk=rhd.buf[g,chan].inds.start+2:2:rhd.buf[g,chan].inds.stop
                                y=(rhd.v[kk,chan]-o)*s+starty
                                if (y<ymin)
                                   y=ymin
                                elseif (y>ymax)
                                   y=ymax
                                end
                                line_to(ctx,startx,y)
                                startx+=1
                            end
                        end
                    end        
                end
	    end
            if chan>length(han.enabled)
                break
            end
	end
	set_line_width(ctx,0.25);
        @inbounds select_color(ctx,thisid)
        stroke(ctx)
    end
    
    identity_matrix(ctx)
    nothing
end

function find_max_id(rhd::RHD2000,han::Gui_Handles,k,num)

    maxid=1
    
    for i=k:(k+num-1)
        if han.enabled[i]
            for g=1:rhd.nums[i]
                if rhd.buf[g,i].id>maxid
                    maxid=rhd.buf[g,i].id
                end
            end
        end
    end
    maxid
end

function draw_raster_n(rhd::RHD2000,han::Gui_Handles,num_chan::Int64)

    k_in=num_chan*(han.num16)-num_chan+1
    
    maxid=find_max_id(rhd,han,k_in,num_chan)
    ctx=getgc(han.c)

    xwidth=width(ctx)
    myheight=height(ctx)
    if num_chan<64
        yheight=300
        myoff=myheight-300.0
    else
        yheight=myheight
        myoff=0.0
    end

    ctx_step=yheight/num_chan
    
    @inbounds for thisid=1:maxid
        count=1
        for i=k_in:(k_in+num_chan-1)
            if han.enabled[i]
                for g=1:rhd.nums[i] #plotting every spike, do we need to do that?  
                    if rhd.buf[g,i].id==thisid
                        offset=myoff+ctx_step*(count-1)
                        move_to(ctx,han.draws,offset)
                        line_to(ctx,han.draws,offset+ctx_step-3.0)
                    end    
                end
            end
            count+=1
        end
    
        set_line_width(ctx,0.5);
        @inbounds select_color(ctx,thisid)
        stroke(ctx)
    end

    nothing
end

draw_raster16(rhd::RHD2000,han::Gui_Handles)=draw_raster_n(rhd,han,16)

draw_raster32(rhd::RHD2000,han::Gui_Handles)=draw_raster_n(rhd,han,32)

draw_raster64(rhd::RHD2000,han::Gui_Handles)=draw_raster_n(rhd,han,64)

function draw_scope(rhd::RHD2000,han::Gui_Handles)

    ctx=getgc(han.c)
    myheight=height(ctx)

    if han.soft.draws>9

        startind=512*(han.soft.draws-1)+1
        for i=1:512
            han.soft.v[startind]=rhd.v[i,han.spike]
            startind+=1
        end
        
        #Paint over old line
        move_to(ctx,1.0,han.soft.last[1])
        for i=2:499
            line_to(ctx,i,han.soft.last[i])
        end

        #Paint over old asterisks
        move_to(ctx,1.0,myheight-4.0)
        line_to(ctx,512.0,myheight-4.0)
        move_to(ctx,1.0,myheight-7.0)
        line_to(ctx,512.0,myheight-7.0)
        
        set_source_rgb(ctx,0.0,0.0,0.0)
        set_line_width(ctx,4.0)
        stroke(ctx)  

        s=han.soft.v_div*-1
        
        #Draw voltage trace from desired channel
        move_to(ctx,1.0,myheight-150.0+han.soft.v[1]*s)
        han.soft.last[1]=myheight-150.0+han.soft.v[1]*s

        t_iter=floor(Int64,han.soft.t_div)

        spike_ind=1
        
        scope_ind=1+t_iter
        for i=2:512
            y=myheight-150.0+han.soft.v[scope_ind]*s
            line_to(ctx,i,y)
            han.soft.last[i]=y
            
            if scope_ind>han.soft.spikes[spike_ind]
                han.soft.prev_spikes[spike_ind]=i
                spike_ind+=1
            end

            scope_ind+=t_iter
        end
        set_source_rgb(ctx,1.0,1.0,1.0)
        set_line_width(ctx,0.5)      
        stroke(ctx)

        #reset spikes
        for i=1:(spike_ind-1)
            move_to(ctx,han.soft.prev_spikes[i],myheight)
            show_text(ctx,"*")
        end
        han.soft.prev_num_spikes=spike_ind-1
        han.soft.num_spikes=0
        
        #draw threshold

        if han.soft.thres_on
            plot_thres_scope(han,rhd,rhd.s[1].d,ctx)
        end

        han.soft.draws=1
    else
        #copy voltage
        startind=512*(han.soft.draws-1)+1
        for i=1:512
            han.soft.v[startind]=rhd.v[i,han.spike]
            startind+=1
        end

        #get spikes
        for g=1:rhd.nums[han.spike]
            han.soft.num_spikes+=1
            han.soft.spikes[han.soft.num_spikes]=rhd.buf[g,han.spike].inds.start+512*(han.soft.draws-1)+1
        end
  
        han.soft.draws+=1
    end

    nothing
end

function plot_thres_scope(han,rhd,d::DetectNeg,ctx)

    myheight=height(ctx)
    
    thres=rhd.s[han.spike].thres*han.soft.v_div

    move_to(ctx,1,myheight-150-thres+2)
    line_to(ctx,500,myheight-150-thres+2)

    move_to(ctx,1,myheight-150-thres-2)
    line_to(ctx,500,myheight-150-thres-2)

    set_line_width(ctx,5.0)
    set_source_rgb(ctx,0.0,0.0,0.0)
    stroke(ctx)

    move_to(ctx,1,myheight-150-thres)
    line_to(ctx,500,myheight-150-thres)
    set_line_width(ctx,1.0)
    set_source_rgb(ctx,1.0,1.0,1.0)
    stroke(ctx)
    
    nothing
end

#Event plotting

function plot_events(rhd::RHD2000,han::Gui_Handles,myreads::Int64)

    @inbounds for i=1:6
	if han.events[i]>-1
	    if han.events[i]<8 #analog
		val=parse_analog(rhd,han,han.events[i]+1)
		plot_analog(rhd,han,i,myreads,val)
	    else
		val=parse_ttl(rhd,han,han.events[i]-7)
		plot_ttl(rhd,han,i,myreads,val)
	    end
	end
    end

    nothing
end

function parse_analog(rhd::RHD2000,han::Gui_Handles,chan::Int64)

    mysum=0
    for i=1:size(rhd.fpga[1].adc,1)
	mysum+=rhd.fpga[1].adc[i,chan]
    end
    
    round(Int64,mysum/size(rhd.fpga[1].adc,1)/0xffff*30)
end

function plot_analog(rhd::RHD2000,han::Gui_Handles,channel::Int64,myreads::Int64,val::Int64)

    ctx=getgc(han.c)
    myheight=height(ctx)
    
    move_to(ctx,myreads-1,myheight-260 + (channel-1)*50-val)
    line_to(ctx,myreads,myheight-260 + (channel-1)*50-val)
    set_source_rgb(ctx,1.0,1.0,0.0)
    stroke(ctx)
    
    nothing
end

function parse_ttl(rhd::RHD2000,han::Gui_Handles,chan::Int64)
   
    y=0
    
    for i=1:length(rhd.fpga[1].ttlin)
        y=y|(rhd.fpga[1].ttlin[i]&(2^(chan-1)))
    end
    
    if y>0
        return true
    else
        return false
    end
end

function plot_ttl(rhd::RHD2000,han::Gui_Handles,channel::Int64,myreads::Int64,val::Bool)

    ctx=getgc(han.c)

    offset=0
    if val==true
	offset=30
    end
    
    move_to(ctx,myreads-1,myheight-260+(channel-1)*50-offset)
    line_to(ctx,myreads,myheight-260+(channel-1)*50-offset)
    set_source_rgb(ctx,1.0,1.0,0.0)
    stroke(ctx)
    
    nothing
end

#=
Single maximized channel plotting
=#

function draw_spike(rhd::RHD2000,han::Gui_Handles)

    spike_num=han.spike
    s=han.scale[han.spike,1]
    o=han.offset[han.spike]
    reads=han.draws

    ctx=getgc(han.c2)
    mywidth=width(ctx)
    myheight=height(ctx)
    Cairo.translate(ctx,0.0,myheight/2)
    scale(ctx,mywidth/han.wave_points,s)
    
    for i=1:rhd.nums[spike_num]

        kk=rhd.buf[i,spike_num].inds.start
        k_end=rhd.buf[i,spike_num].inds.stop
        if (kk>0) & (k_end<size(rhd.v,1))
        
            move_to(ctx,1,rhd.v[kk,spike_num]-o)
            
            for k=2:han.wave_points
                y = rhd.v[kk+k-1,spike_num]-o
                line_to(ctx,k,y)
            end
			
	    set_line_width(ctx,0.5);
	    @inbounds select_color(ctx,rhd.buf[i,spike_num].id)
	    stroke(ctx)

            #Add spike to buffer
            if han.buf_count > 0
                mycount=1
                for k=1:han.wave_points
                    han.spike_buf[mycount,han.buf_ind] = rhd.v[kk+k-1,spike_num]
                    mycount+=1
                end
                han.buf_clus[han.buf_ind] = rhd.buf[i,spike_num].id-1
                han.buf_count+=1
                han.buf_ind+=1
                if han.buf_count>500
                    han.buf_count=500
                end
                if han.buf_ind>500
                    han.buf_ind=1
                end
            end

            update_isi(rhd,han,i)
        end
    end

    identity_matrix(ctx)
    
    nothing
end

identity_matrix(ctx)=ccall((:cairo_identity_matrix,Cairo._jl_libcairo),Void, (Ptr{Void},), ctx.ptr)

function update_isi(rhd::RHD2000,han::Gui_Handles,i)

    spike_num=han.spike
    clus=rhd.buf[i,spike_num].id
    mytime=rhd.time[rhd.buf[i,spike_num].inds.start,1]

    my_isi = mytime - han.isi_last_time[clus]

    han.isi_last_time[clus] = mytime

    han.isi[han.isi_ind] = my_isi

    han.isi_clus_ID[han.isi_ind] = clus

    han.isi_ind+=1
    if han.isi_ind>500
        han.isi_ind=1
    end

    han.isi_count+=1
    if han.isi_count>500
        han.isi_count=500
    end
    
    nothing
end

function draw_isi(rhd::RHD2000,han::Gui_Handles)

    ctx=Cairo.getgc(han.c3)
    
    for i=1:han.total_clus[han.spike]        

        mycount=0
        myviolation=0
        for j=1:han.isi_count
            if han.isi_clus_ID[j] == i+1
                if han.isi[j]/rhd.sr < .0025
                   myviolation += 1
                end
                mycount+=1

                ind=1
                this_isi = han.isi[j]/rhd.sr
                for k=.001:.001:.049
                    if (this_isi > k - .001)&(this_isi < k)
                        han.isi_hist[ind]+=1
                    end
                    ind+=1
                end
            end
        end

        isi_f=round(myviolation/mycount*100,2)
        if isi_f>5.0
            set_source_rgb(ctx,1.0,0.0,0.0)
        else
            set_source_rgb(ctx,1.0,1.0,1.0)
        end
        move_to(ctx,(i-1)*100+1,10)
        show_text(ctx,string(isi_f))

        set_source_rgb(ctx,1.0,1.0,1.0)
        move_to(ctx,(i-1)*100+21,130)
        line_to(ctx,(i-1)*100+21,80)
        move_to(ctx,(i-1)*100+21,130)
        line_to(ctx,(i-1)*100+71,130)

        stroke(ctx)

        select_color(ctx,i+1)
        move_to(ctx,(i-1)*100+21,130)
        line_to(ctx,(i-1)*100+21,130-han.isi_hist[1]*6)
        han.isi_hist[1]=0

        for j=2:length(han.isi_hist)
            move_to(ctx,(i-1)*100+j+20,130)
            line_to(ctx,(i-1)*100+j+20,130-han.isi_hist[j]*6)
            han.isi_hist[j]=0
        end
        stroke(ctx)
    end
    
    nothing
end

#=
Reset Canvas
=#

function clear_c(han::Gui_Handles)

    #paint it black
    ctx = getgc(han.c)
    set_source_rgb(ctx,0.0,0.0,0.0)
    paint(ctx)

    if han.c_right_top==1
        prepare_16(ctx,han)
    elseif han.c_right_top==2
        prepare_32(ctx,han)
    elseif han.c_right_top==3
        prepare_64(ctx,han)
    else
    end

    if han.c_right_bottom==1
        prepare_events(ctx,han)
    elseif han.c_right_bottom==2
    elseif han.c_right_bottom==3
    elseif han.c_right_bottom==4
        prepare_scope(ctx,han)
    elseif han.c_right_bottom==5
    else
        
    end
    nothing
end

function prepare_16(ctx::Cairo.CairoContext,han::Gui_Handles)
    
    mywidth=width(ctx)
    myheight=height(ctx)-300

    for x in linspace(0,mywidth,5)
	move_to(ctx,x,1)
	line_to(ctx,x,myheight)
    end
    for y in linspace(0,myheight,5)
	move_to(ctx,1,y)
	line_to(ctx,mywidth,y)
    end
    set_source_rgb(ctx,1.0,1.0,1.0)
    set_line_width(ctx,1.0)
    stroke(ctx)

    xwidth=mywidth/4
    ywidth=myheight/4
    k=16*han.num16-15
    for x in 0.0:xwidth:(3*xwidth)
        for y in 0.0:ywidth:(3*ywidth)
            if k<=length(han.enabled)
                move_to(ctx,x+10.0,y+10.0)
                if han.enabled[k] 
                    show_text(ctx,string(k))
                else
                    show_text(ctx,string(k,"-DISABLED"))
                end
            end
            k+=1
        end
    end

    (x1_f,x2_f,y1_f,y2_f)=get_multi_dims(han,4,4,16,han.num)
    draw_box(x1_f,y1_f,x2_f,y2_f,(1.0,0.0,1.0),1.0,ctx)

    nothing
end

function prepare_32(ctx::Cairo.CairoContext,han::Gui_Handles)

    mywidth=width(ctx)
    myheight=height(ctx)-300

    for x in linspace(0,mywidth,7)
	move_to(ctx,x,1)
	line_to(ctx,x,myheight)
    end
    for y in linspace(0,myheight,7)
	move_to(ctx,1,y)
	line_to(ctx,mywidth,y)
    end
    set_source_rgb(ctx,1.0,1.0,1.0)
    set_line_width(ctx,1.0)
    stroke(ctx)

    xwidth=mywidth/6
    ywidth=myheight/6
    k=32*han.num16-31
    for x in 0.0:xwidth:(5*xwidth)
        for y in 0.0:ywidth:(5*ywidth)
            if k<=length(han.enabled)
                move_to(ctx,x+10.0,y+10.0)
                if han.enabled[k] 
                    show_text(ctx,string(k))
                else
                    show_text(ctx,string(k,"-DISABLED"))
                end
            end
            k+=1
        end
    end

    (x1_f,x2_f,y1_f,y2_f)=get_multi_dims(han,6,6,32,han.num)
    draw_box(x1_f,y1_f,x2_f,y2_f,(1.0,0.0,1.0),1.0,ctx)

    nothing
end

function prepare_64(ctx::Cairo.CairoContext,han::Gui_Handles)
    
    mywidth=width(ctx)
    myheight=height(ctx)

    for x in linspace(0,mywidth,7)
	move_to(ctx,x,1)
	line_to(ctx,x,myheight)
    end
    for y in linspace(0,myheight,12)
	move_to(ctx,1,y)
	line_to(ctx,mywidth,y)
    end
    set_source_rgb(ctx,1.0,1.0,1.0)
    set_line_width(ctx,1.0)
    stroke(ctx)

    xwidth=mywidth/6
    ywidth=myheight/11
    k=64*han.num16-63
    for x in 0.0:xwidth:(5*xwidth)
        for y in 0.0:ywidth:(10*ywidth)
            if k<=length(han.enabled)
                move_to(ctx,x+10.0,y+10.0)
                if han.enabled[k] 
                    show_text(ctx,string(k))
                else
                    show_text(ctx,string(k,"-DISABLED"))
                end
            end
            k+=1
        end
    end

    (x1_f,x2_f,y1_f,y2_f)=get_multi_dims(han,6,11,64,han.num)
    draw_box(x1_f,y1_f,x2_f,y2_f,(1.0,0.0,1.0),1.0,ctx)

    nothing
end

function prepare_raster16(ctx)
end

function prepare_raster32(ctx)
end

function prepare_events(ctx,han)

    myheight=height(ctx)

    for y in collect((myheight-250.0):50.0:(myheight-50.0))
	move_to(ctx,1.0,y)
	line_to(ctx,500.0,y)
    end
    set_source_rgb(ctx,1.0,1.0,1.0)
    set_line_width(ctx,1.0)
    stroke(ctx)

    for i=1:6
	if han.events[i]>-1
            move_to(ctx,10,(myheight-340)+i*50)
	    if han.events[i]<8 #analog
		show_text(ctx,string("A",han.events[i]))
	    else
		show_text(ctx,string("TTL",han.events[i]-8))
	    end
	end
    end
    
    nothing
end

function prepare_scope(ctx,han)
end
    
function clear_c2(myc::Gtk.GtkCanvas,num)
        
    ctx = getgc(myc)
    mywidth=width(ctx)
    myheight=height(ctx)

    set_source_rgb(ctx,0.0,0.0,0.0)
    paint(ctx)

    dashes = [10.0,10.0,10.0]
    set_dash(ctx, dashes, 0.0)
    
    for y = [myheight/6, myheight/3, myheight/2, myheight/6*4, myheight/6*5]
        move_to(ctx,1,y)
        line_to(ctx,mywidth,y)
    end

    for x = [.2*mywidth, .4*mywidth, .6*mywidth, .8*mywidth]
        move_to(ctx,x,1)
        line_to(ctx,x,myheight)
    end

    set_source_rgba(ctx,1.0,1.0,1.0,.5)
    stroke(ctx) 
    
    set_dash(ctx,Float64[])
    
    move_to(ctx,1,myheight)
    line_to(ctx,mywidth,myheight)
    set_source_rgb(ctx,1.0,1.0,1.0)
    stroke(ctx)

    move_to(ctx,1,myheight/2)
    line_to(ctx,mywidth,myheight/2)
    stroke(ctx)

    move_to(ctx,10,10)
    show_text(ctx,string(num))
    
    nothing
end

function clear_c3(c3,num)

    ctx = getgc(c3)

    set_source_rgb(ctx,0.0,0.0,0.0)
    paint(ctx)
    
    nothing
end

function select_color(ctx,clus,alpha=1.0)

    if clus==1
        set_source_rgba(ctx,1.0,1.0,1.0,alpha) # white
    elseif clus==2
        set_source_rgba(ctx,1.0,1.0,0.0,alpha) #Yellow
    elseif clus==3
        set_source_rgba(ctx,0.0,1.0,0.0,alpha) #Green
    elseif clus==4
        set_source_rgba(ctx,0.0,0.0,1.0,alpha) #Blue
    elseif clus==5
        set_source_rgba(ctx,1.0,0.0,0.0,alpha) #Red
    else
        set_source_rgba(ctx,1.0,1.0,0.0,alpha)
    end
    
    nothing
end

#Replots spikes assigned to specified cluster 
function plot_new_color(ctx::Cairo.CairoContext,han::Gui_Handles,clus::Int64)

    s=han.scale[han.spike,1]
    o=han.offset[han.spike]
    mywidth=width(ctx)
    myheight=height(ctx)

    Cairo.translate(ctx,0.0,myheight/2)
    scale(ctx,mywidth/han.wave_points,s)

    #Plot Noise
    select_color(ctx,1)
    @inbounds for i=1:han.buf_ind

        if han.buf_clus[i]==0
            move_to(ctx,1,(han.spike_buf[1,i]-o))
            for j=2:size(han.spike_buf,1)
                line_to(ctx,j,han.spike_buf[j,i]-o)
            end
        end
    end
    stroke(ctx)

    #Plot New color
    select_color(ctx,clus+1)
    
    @inbounds for i=1:han.buf_ind

        if han.buf_clus[i]==clus
            move_to(ctx,1,(han.spike_buf[1,i]-o))
            for j=2:size(han.spike_buf,1)
                line_to(ctx,j,han.spike_buf[j,i]-o)
            end
        end
    end
    stroke(ctx)

    identity_matrix(ctx)
    reveal(han.c2)

    nothing
end

function draw_c3(rhd::RHD2000,han::Gui_Handles)

    ctx=Cairo.getgc(han.c3)

    spike_num=han.spike
    reads=han.draws

    for i=1:rhd.nums[spike_num]
    
        @inbounds move_to(ctx,reads,(rhd.buf[i,spike_num].id-1)*10.0+150.0)
        @inbounds line_to(ctx,reads,(rhd.buf[i,spike_num].id-1)*10.0+160.0)
        set_line_width(ctx,0.5);
	@inbounds select_color(ctx,rhd.buf[i,spike_num].id)
	stroke(ctx)
    end

    if reads==1
        draw_templates(rhd,han)
        draw_isi(rhd,han)
    end

    nothing
end
