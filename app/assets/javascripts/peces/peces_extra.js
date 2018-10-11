var limpiaBusqueda = function(){
    $(".agrupada *, .recomendada *, #nombre").attr("disabled", false).removeClass("disabled");
    $( "#especie_id, #nombre" ).val('');
};

var bloqueaBusqueda = function(){
};

$(document).ready(function(){
    TYPES = ['peces'];
    soulmateAsigna('peces');

    //$('[data-toggle="popover"]').popover();

/*
    $('[data-toggle="popover"]').popover({
        html:true,
        container: 'body',
        placement:'bottom',
        title: 'Criterios',
        content:function() {
            var button = $(this);
            var idEspecie = $(button).data('especie-id');
            var pestaña = '/peces/'+idEspecie+'?mini=true';
            //console.log(pestaña);
            //response = jQuery.get(pestaña)['responseText'];
            //console.log(response['responseText']);
            return pestaña;
        }
    });
*/

    $('[data-toggle="popover"]').one('click', function(){
        var button = $(this);
        var idEspecie = $(button).data('especie-id');
        var pestaña = '/peces/'+idEspecie+'?mini=true';
        jQuery.get(pestaña).done(function(data){
            button.popover({
                html:true,
                container: 'body',
                placement:'bottom',
                title: 'Criterios',
                trigger: 'focus',
                content: data
            }).popover('show');
        });
    });


    $('#multiModal').on('show.bs.modal', function (event) {
        var button = $(event.relatedTarget); // Button that triggered the modal IMPORTANTE
        var idEspecie = $(button).data('especie-id');
        var pestaña = '/peces/'+idEspecie+'?layout=0 #panel-body';
        $('#multiModalBody').load(pestaña);
        $('.modal-header').append(button.siblings('.result-nombre-container').children('h5').clone());
    });

    //Eliminar contenido del modal-body y modal header (para poder reutilizar el modal en peces)
    $('#multiModal').on('hide.bs.modal', function(){
        $('#multiModalBody').empty();
        $('.modal-header h5').remove();
    });

    $("path[id^=path_zonas_]").on('click', function(){
        $(this).toggleClass('zona-seleccionada');
        var input = $('#' + this.id.replace('path_',''));
        input.prop("checked", !input.prop("checked"));
    });

    //$(window).load(function(){
        $("html,body").animate({scrollTop: 105}, 500);
    //});
});

var scroll_array = false;

var scrollToAnchor = function(){
    if(scroll_array){
        $("html,body").animate({scrollTop: $('#busqueda_avanzada').offset().top},'slow');
        scroll_array =  false;
    }else{
        $('html,body').animate({scrollTop: $('#scroll_down_up').offset().top},'slow');
        scroll_array = true;
    }
    $('#scroll_down_up span').toggleClass("glyphicon-menu-down glyphicon-menu-up");
};