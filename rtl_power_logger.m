1+1; % suppress warning

function flat_db = get_db()

    frequency_low=130;
    frequency_high=800;
    frequency_step=0.01;
    integration_interval=15;
    crop_ratio=0.4;

    cmdline=strcat('rtl_power',
                ' -f', num2str(frequency_low),'M:',num2str(frequency_high),'M:',num2str(frequency_step),'M ',
                ' -c ', num2str(crop_ratio),
                ' -i ', num2str(integration_interval),
                ' -1 ',
                ' 2> /dev/null'
                );

    f=popen(cmdline,'r');

    flat_db=[,];

    while ((s=fgets(f))~=(-1)) 

        sixt_comma=0;
        
        for i = 1:numel(s)
            
            if s(i) == ','
                sixt_comma=sixt_comma+1;
            end
            
            if sixt_comma == 2
                sixt_comma = i+1;
                break;
            end
        end
        
        arr=textscan(s(sixt_comma:end), '%f', 'delimiter',',');     # date, time, Hz low, Hz high, Hz step, samples, dbm, dbm, ..., dbm
        
        
        arr=(cell2mat(arr));

        hz_low=arr(1);
        hz_step=arr(3);
        
        
        count=linspace(1,numel(arr)-4,numel(arr)-4);

        hz_arr = hz_low .+ ((count) .* hz_step)';


        flat_db=[flat_db; [hz_arr, arr(5:end)]];
    
    end #while
end #function



function ret = gqrx_bookmarks()
    fd = fopen(strcat(getenv('HOME'),'/.config/gqrx/bookmarks.csv'));
    ret = [];
    tline = fgets(fd);

    while ischar(tline)
        
        arr=textscan(tline, '%s', 'delimiter',';'); 
        arr=(cell2mat(arr));

        if size(arr) == [5 1]
            freq=str2num(arr{1});
            if isnumeric(freq)
                ret=[ret freq];
            end
        end
        tline = fgets(fd);
    end

    fclose(fd);

end % function


function my_plot(flat_db)
    graphics_toolkit('gnuplot');
    plot(flat_db(:,1),flat_db(:,2));
    xlabel('Frequenza');
    
    %print(strcat('out/',ctime(time()) ),'-dpng','-S4000,2000');
    axis([flat_db(1,1) flat_db(end,1) -50 10])

end


function image_append(image_path,data)

    persistent image=-1;
    persistent save=int32(1);
    
    if image==-1
        if exist(image_path,'file')
            image=imread(image_path);
        elseif
            disp('file not found, creating');
    
            freqs=data(:,1)'; % horizontal vector with frequencies
        
            meter=ones( size(freqs ) )*65536;
            image=ones( size(freqs ) )*65536;

            % mark gqrx bookmarks on the scale
            % warning: algorithm is not efficient
            for freq=gqrx_bookmarks()
                for j=1:size(freqs)(2)  
                    if freqs(j) > freq
                        meter(j)=32768; % gray color
                        break;
                    end
                end
            end
            
            for freq=[100000000 1000000] % draw scale
                
                base_mhz=freqs(1)-mod(freqs(1), freq)+freq; % find last multiple of freq
                step_mhz = freqs(2) - freqs(1); % get frequency step from data
            
                search_next=base_mhz;
        
                for j=1:size(freqs)(2)  
                    if freqs(j) > search_next
                        meter(j)=0;
                        if size(meter)(2) > j+1 %make the lines 2 pixels thick, avoiding breakage
                            meter(j+1)=0;
                        end
                        
                        search_next+=freq;
                    end
                end
                
                
                for j=1:10
                    size(image);
                    size(meter);
                    image=vertcat(image,meter);
                end
            end % for
        end % if
    end % if image exist
        
    row=data(:,2)';
    new_line=uint16((40+row)*1638);
    
    if size(image) ~= size(new_line)
        disp('are you trying to append to the wrong image?');
    end
    
    image=vertcat(image,new_line);
    

    if mod(save++,10)==0  %save every 10 appends, for performance
        disp('**WRITING');
        imwrite(image,image_path);
    end
end % function


function ret = gqrx_bookmarks()
    fd = fopen(strcat(getenv('HOME'),'/.config/gqrx/bookmarks.csv'));
    ret = [];
    tline = fgets(fd);

    while ischar(tline)
        
        arr=textscan(tline, '%s', 'delimiter',';'); 
        arr=(cell2mat(arr));

        if size(arr) == [5 1]
            freq=str2num(arr{1});
            if isnumeric(freq)
                ret=[ret freq];
            end
        end
        tline = fgets(fd);
    end

    fclose(fd);

end % function



image_path='/tmp/waterfall.png';

i=1;
while i++
    disp(strcat(num2str(i), '_', ctime (time ())));
    image_append(image_path,get_db());
end
