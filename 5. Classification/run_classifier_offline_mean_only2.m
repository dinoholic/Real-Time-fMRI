% run classification for all scan sessions
run ~/Desktop/scripts/rtfMRI_import_responses_round_plus1.m

path.feat = '~/Desktop/FEAT_group_analysis/transformed_contrasts_contrasts/';
path.save = '~/Desktop/rtfMRI Reports/13:3:21';

rest_num = 1;
dmn_seed = 1;
dmn_corr_thresh = .33;


number_thresholds = 30;

prep_initial_shift = -1;
tr_sec = 2;

fig_area_color = [.7 .7 .7];
fig_press_color = [.7 0 0];

z_dmn = -2.3;
z_smn = 8;

for s = 4%[4 6 7 8 10]
    fprintf('\n\nSubject %d',s)
    for r = 1%:5
        fprintf('\n Run %d',r)
        cd('/Users/george/Data/rtfMRI/August/subjects/preprocessed/dmn/transformed_dmn_maps/')

        path.func = sprintf('/Users/george/Data/rtfMRI/August/Processing/subject%d/run%d_elliot.nii.gz',s,r);
        path.func_hipass = sprintf('/Users/george/Data/rtfMRI/August/subjects/filtered/subject%d_run%d_hi_pass_5.nii.gz',s,r);
        path.zmap = sprintf('%ssubject%d_run%d_contrast1_exclude%d_mni_1mm_in_func.nii.gz',path.feat,s,r,s);
        path.dmn = sprintf('subject%d_rest%d_dmn%d_IN_run%d.nii.gz',s,rest_num,dmn_seed,r);

        func = MRIread(path.func);
        func_hipass = MRIread(path.func_hipass);
        zmap = MRIread(path.zmap);
        dmn_map = MRIread(path.dmn);

        cd('/Users/george/dev/rtfMRI_classifier')
        %%
        dmn_map_vol = zeros(size(dmn_map.vol));
        dmn_map_vol(find(dmn_map.vol>dmn_corr_thresh)) = 1;

        thresholded_zmap_dmn = zeros(size(zmap.vol));
        thresholded_zmap_dmn(find(zmap.vol<z_dmn)) = 1;
        thresholded_zmap_dmn = thresholded_zmap_dmn .* dmn_map_vol;

        %%
        thresholded_zmap_smn = zeros(size(zmap.vol));
        thresholded_zmap_smn(find(zmap.vol>z_smn)) = 1;

        thresholded_zmap_smn(size(thresholded_zmap_smn,1):-1:floor(size(thresholded_zmap_smn,1)-size(thresholded_zmap_smn,1)/2.2),:,:) = 0;
        thresholded_zmap_smn(1:floor(size(thresholded_zmap_smn,1)/4.5),:,:) = 0;
        thresholded_zmap_smn(:,1:floor(size(thresholded_zmap_smn,2)/2),:) = 0;
        thresholded_zmap_smn(:,:,1:floor(size(thresholded_zmap_smn,3)/2)) = 0;

%         vol3d_mri(thresholded_zmap_smn)

        %%

        matrix = rtfMRI_volume2matrix(mask_volume(func.vol,thresholded_zmap_smn));
%         matrix = rtfMRI_volume2matrix(mask_volume(func_hipass.vol,thresholded_zmap_smn));
        matrix_hi = rtfMRI_volume2matrix(mask_volume(func_hipass.vol,thresholded_zmap_dmn));

        mean_smn = mean(matrix);
        mean_dmn = mean(matrix_hi);
        %%

        feature_dmn{1} = mean_dmn;
        feature_dmn_index{1} = 1:size(feature_dmn{1},2);
        [feature_dmn{2} feature_dmn_index{2}] = feature_derivative(mean_dmn);
        
        feature_smn{1} = mean_smn;
        feature_smn_index{1} = 1:size(feature_smn{1},2);
        [feature_smn{2} feature_smn_index{2}] = feature_derivative(mean_smn);

        [feature_both{1} feature_both_index{1}] = feature_anticorr(mean_dmn,mean_smn);
        [feature_both{2} feature_both_index{2}] = feature_anticorr_multi(mean_dmn,mean_smn);


        %%

        for bold_shift = [2 3]           
            %%
            feature_vector = feature_both{1};
            index_vector = feature_both_index{1};
            feature_title = 'DMN & SMN BOLD derivative substraction';
            
            t0 = response(s,r).rest_response + bold_shift;       % get all responce event volumes
            tp = response(s,r).prep_onset + bold_shift;
            tr = [1; response(s,r).rest_response(1:numel(response(s,r).rest_response)-1)+1] + bold_shift;
            
            detection_table = zeros([number_thresholds numel(t0)*2]);
            
            for t = 0:numel(t0)
                rest_index = [];
                prep_index = [];
                for j = 1:length(tp)
                    if j==t
                        rest_index_t = tr(j):tp(j)-1+prep_initial_shift;
                        prep_index_t = tp(j)+prep_initial_shift:t0(j);

                    else
                        rest_index = [rest_index tr(j):tp(j)-1+prep_initial_shift];
                        prep_index = [prep_index tp(j)+prep_initial_shift:t0(j)];
                    end
                end

                if ~isempty(intersect(rest_index,prep_index))
                    intersect(rest_index,prep_index)
                    error('Indexes of resting and preping vactors intersect.')
                end
                %%
                rest_index = intersect(index_vector,rest_index);
                prep_index = intersect(index_vector,prep_index);
                
                if t == 0
                    if numel(rest_index) > numel(prep_index)
                        plot_feature_matrix = [ feature_vector(rest_index)' [feature_vector(prep_index) linspace(NaN,NaN,numel(rest_index) - numel(prep_index))]' ];
                    end
                    if numel(rest_index) < numel(prep_index)
                        plot_feature_matrix = [ [feature_vector(rest_index) linspace(NaN,NaN,numel(prep_index) - numel(rest_index))]' feature_vector(prep_index)'];
                    end
                    if numel(rest_index) == numel(prep_index)
                        plot_feature_matrix = [feature_vector(rest_index)' feature_vector(prep_index)'];
                    end
                    
                    close all
                    boxplot(plot_feature_matrix);
                    boxplot_title = sprintf('Box plot of feature values (%s) \nLevels: Rest ? 1, Prep ? 2',feature_title);
                    title(boxplot_title)
                    saveas(gca,sprintf('%s/boxplots/%s s%d r%d shift%d.png',path.save,feature_title,s,r,bold_shift))
                    
                    close all
                    hold on
                    hist(plot_feature_matrix);
                    legend({'Rest';'Prep'})
                    hist_title = sprintf('Histogram of feature values (%s)',feature_title);
                    title(hist_title)
                    saveas(gca,sprintf('%s/histograms/%s s%d r%d shift%d.png',path.save,feature_title,s,r,bold_shift))
                else
                    %%

                    rest_feature_vector = feature_vector(:,rest_index_t);
                    prep_feature_vector = feature_vector(:,prep_index_t);
                    
                    threshold = linspace(max([feature_vector(prep_index) feature_vector(rest_index)]),min([feature_vector(prep_index) feature_vector(rest_index)]),number_thresholds);
                    
                    for thresh = 1:numel(threshold)
                        if max(rest_feature_vector < threshold(thresh)) ~= 0
                            if detection_table(thresh,2*t-1) ~= 0
                                error('Detection value already exists')
                            end
                            detection_table(thresh,2*t-1) = 1;
                        end
                        if max(prep_feature_vector < threshold(thresh)) ~= 0
                            if detection_table(thresh,2*t) ~= 0
                                error('Detection value already exists')
                            end
                            detection_table(thresh,2*t) = 2;
                        end
                    end
                    
                    class_result.wrong = [];
                    class_result.right = [];
                    for j=1:size(detection_table,1)
                        class_result.wrong = [class_result.wrong numel(find(detection_table(j,:) == 1))/numel(t0)];
                        class_result.right = [class_result.right numel(find(detection_table(j,:) == 2))/numel(t0)];
                        class_result.overall = mean([1-class_result.wrong' class_result.right' ]');
                    end
                    
                end                
            end

            close all
            hold on
            plot(class_result.wrong,class_result.right,'b','linewidth',2)
            plot(0:1,0:1,'k','linewidth',1)
            xlabel('False positive rate'),ylabel('True positive rate'),daspect([1 1 1])
            roc_title = sprintf('ROC of feature values (%s)',feature_title);
            title(roc_title)
            saveas(gca,sprintf('%s/roc/%s s%d r%d shift%d.png',path.save,feature_title,s,r,bold_shift))


            export_table = [threshold' detection_table class_result.wrong' class_result.right' class_result.overall'];
            xlswrite(sprintf('%s/csv/%s s%d r%d shift%d.csv',path.save,feature_title,s,r,bold_shift),export_table)

            %%

            prep_duration = response(s,r).rest_response - response(s,r).prep_onset;

            plot_line = feature_vector;
%             plot_line = feature_dmn{2};
            plot_line = [zeros([1 size(matrix,2)-size(plot_line,2)]) plot_line];
            fig_line_color = 'b';

            time_index = (0:tr_sec:tr_sec*(size(matrix,2)-1))-bold_shift*tr_sec;

            close all
            h = figure('position',[1 500 1900 300]);
            hold on
            for p = 1:length(prep_duration)
                area(tr_sec*[tp(p) tp(p)+prep_duration(p)],[max(plot_line) max(plot_line)],'facecolor',fig_area_color,'edgecolor',fig_area_color);
                area(tr_sec*[tp(p) tp(p)+prep_duration(p)],[min(plot_line) min(plot_line)],'facecolor',fig_area_color,'edgecolor',fig_area_color);
            end
            for p = 1:length(t0)
                area(tr_sec*[t0(p) t0(p)+.1],[max(plot_line(:)) max(plot_line(:))],'facecolor',fig_press_color,'edgecolor',fig_press_color);
                area(tr_sec*[t0(p) t0(p)+.1],[min(plot_line(:)) min(plot_line(:))],'facecolor',fig_press_color,'edgecolor',fig_press_color);
            end

            plot(time_index,mean_smn-mean(mean_smn(:)),'color',[1 .7 .7],'linewidth',1)
            plot(time_index,mean_dmn-mean(mean_dmn(:)),'color',[.7 1 .7],'linewidth',1)
            
%             plot(time_index,plot_line,'color',fig_line_color,'linewidth',2)
            scatter(time_index,plot_line,7)

            textTitle = sprintf('%s of Subject %d, Session %d (Time Shift %d s.)',feature_title,s,r,bold_shift*tr_sec);
            title(textTitle,'FontName','Monaco','FontSize',13)
            set(gca,'LooseInset',get(gca,'TightInset'))
            set(h,'PaperPositionMode','auto');
            box off

            ylim([min(plot_line(:)) max(plot_line(:))])
            xlim([min(time_index) max(time_index)])

            title(roc_title)
            saveas(gca,sprintf('%s/feature_plots/%s s%d r%d shift%d.png',path.save,feature_title,s,r,bold_shift))

        
        end
    end
end
fprintf('\nDone.\n')















































