using FileIO
using Images
using ImageSegmentation
using Statistics
using HDF5

"""
Version Comment
0.1		initial 
0.2		only LoG
"""

"""
Generate border form watershed result
"""
function watershedborder(watershed_segments)
    marker_border = BitArray(undef, size(watershed_segments.image_indexmap));
    marker_border .= false
    for label in watershed_segments.segment_labels
        marker_border .|= ((watershed_segments.image_indexmap.==label) .⊻ erode(watershed_segments.image_indexmap .==label));
    end
    marker_border;
end

"""
Use LoG fiter raw image to extract cell
"""
function split_cell_LoG(stack::Array{Gray{Normed{UInt16,16}},3}, time::Int)
	println("Applying LoG(40) at MZJ")
    img_edge = zeros(N0f16, 1900, 1300, time);
    mask_edge = zeros(Int16, 1900, 1300, time);
    mask_markers = zeros(Int16, 1900, 1300, time);
	GC.gc() # garbage clean imediately to avoid double free insize threads.@threads
    Threads.@threads for i in 1:time  #use 40 threads slow down speed. may due to gc time
		# remove possion noise with median filter
		#imgx = mapwindow(median!, stack[:, :, 20*(i-1)+14], (5,5));
		imgx = mapwindow(median!, maximum(stack[:, :, 20*(i-1)+1:20*i],dims=3)[:,:,1], (5,5));
		# using maximum z projection
		# extract intensity info with LoG
        mask_markers[:,:,i] = imfilter(imgx, Kernel.LoG(40)) .< -1e-7 ;
        #imgx_dist = distance_transform(feature_transform(imgx_log));
		# filter markers for watershed
        #imgx_markers = label_components( imgx_dist .> 50);
		#mask_markers[:,:,i] = imgx_markers
        #imgx_segments = watershed( imfilter(1 .- imgx, Kernel.gaussian(9)), imgx_markers);
        #img_edge[:,:,i] = .~watershedborder(imgx_segments).*imgx;
        #mask_clear[:,:,i] = extract_nucleus( imgx, imgx_segments) .> 0;
		#mask_edge[:,:,i] = imgx_segments.image_indexmap;
        print("*");
    end
	println("Done")
    mask_markers;
end

# TODO: A simple version just use LoG then, only export only longlived and no branches cell.

# TODO: run again and again until best fitting
"""
Extract nucleus from sperated cell
"""
function extract_nucleus( img, watershed_segments::SegmentedImage{Array{Int64,2},Float64} )
    img_clear = zeros(N0f16, size(watershed_segments.image_indexmap));
    img_blur = imfilter(img, Kernel.gaussian(9));
    for label in watershed_segments.segment_labels
        cell = img_blur .* (watershed_segments.image_indexmap .== label);
        # only select 70% brigter region or fixed area
        gmm = GMM(3, [pixel for pixel in real(cell) if pixel > 1e-5]);
        nucleus_th = sort(gmm.μ, dims=1)[end-1];
        img_clear .+= ( remove_small_area(cell .> nucleus_th)) .*img;
    end
    img_clear;
end

"""
Just remove regions are small
"""
function remove_small_area(mask)
    mask_con = label_components(mask);
    mask_res = BitArray(undef, size(mask));
    mask_res .= false;cd
    for i in 1:maximum(mask_con)
        if sum(mask_con .== i) > 5e3
            mask_res .+= (mask_con.==i);
        end
    end
    mask_res;
end
#data_dir = "/datahub/rawdata/tandeng/mRNA_imaging/mRNA_confocal_hamamatsu-60X-TIRF";
#img_16_2 = load(File(format"TIFF", "$data_dir/20200316/HE7-11-1-80uw-PWM_1_s2.ome.tiff"));

#@time edge, clear = split_cell_LoG(img_16_2, 137);
#res_dir = "/datahub/rawdata/tandeng/mRNA_imaging/CoutingmRNA.jl"
#save("output/img_16_2_edge_all.tiff", edge);
#save("output/img_16_2_clear_all.tiff", clear);
#h5write("output/img_16_2_clear_all.h5", "img", rawview(clear));