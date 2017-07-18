$(document).ready(function() {

    // modify thumbnail links in wiki content -> add filename to url to support fancybox preview
    $("div.wiki a.thumbnail").attr('href', function(i, v){
      return v.replace(/\/attachments\/(\d+)/g,'/attachments/download/$1') + '/' + $(this).attr('title').replace(/(.*\.[^.]*)\s\(.*\)/g,'$1');
    });

    // modify thumbnails and magnifier links in journal details -> add filename to url to support fancybox preview
    $("div.journal div.thumbnails a, div.journal ul.details li a.icon-magnifier").attr('href', function(i, v){
      return v.replace(/\/attachments\/(\d+)/g,'/attachments/download/$1');
    });

    // add rel attribute to detail links of the same journal entry
    $("div.journal ul.details li a.icon-magnifier").attr('rel', function(i, v){
      return 'image-details-' + $(this).closest('div.journal').attr('id');
    });

    // add rel attribute to thumbnails of the same journal entry
    $("div.journal div.thumbnails a").attr('rel', function(i, v){
      return 'thumbnails-' + $(this).closest('div.journal').attr('id');
    });

	$("div.attachments a.lightbox," +
      "div.attachments a.lightbox_preview," +
	  "div.journal ul.details a[href$='.png']," +
	  "div.journal ul.details a[href$='.PNG']," +
	  "div.journal ul.details a[href$='.jpg']," +
	  "div.journal ul.details a[href$='.JPG']," +
	  "div.journal ul.details a[href$='.jpeg']," +
	  "div.journal ul.details a[href$='.JPEG']," +
	  "div.journal ul.details a[href$='.gif']," +
	  "div.journal ul.details a[href$='.GIF']," +
	  "div.journal div.thumbnails a," +
	  "div.wiki a.thumbnail," +
	  "div.attachments a.swf," +
	  ".avatar a").fancybox({
			prevEffect		: 'none',
			nextEffect		: 'none',
			openSpeed		: 300,
			closeSpeed		: 150
		});

    $("div.attachments a.pdf").fancybox({
			prevEffect		: 'none',
			nextEffect		: 'none',
			openSpeed		: 300,
			closeSpeed		: 150,
			width			: '90%',
			height			: '90%',
			autoSize		: true,
			iframe : {
				preload: false
			}
		});
});
