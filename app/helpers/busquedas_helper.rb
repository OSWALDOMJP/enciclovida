module BusquedasHelper

  # REVISADO: Filtros para los grupos icónicos en la búsqueda avanzada vista general
  def radioGruposIconicos
    def arma_span(taxon)
      "<label>#{radio_button_tag('id_gi', taxon.id, false, id: "id_gi_#{taxon.id}")}<span title='#{taxon.nombre_comun_principal}' class='#{taxon.nombre_cientifico.parameterize}-ev-icon btn btn-xs btn-basica btn-title'></span></label>"
    end

    radios = '<h6><strong>Reinos</strong></h6>'
    @reinos.each do |taxon|  # Para tener los grupos ordenados
      radios << arma_span(taxon)
    end
    radios << '<hr />'

    radios << '<h6><strong>Grupos de animales</strong></h6>'
    @animales.each do |taxon|  # Para tener los grupos ordenados
      radios << arma_span(taxon)
    end
    radios << '<hr />'
    radios << '<h6><strong>Grupos de plantas</strong></h6>'
    @plantas.each do |taxon|  # Para tener los grupos ordenados
      radios << arma_span(taxon)
    end

    "<div>#{radios}</div>"
  end

  # REVISADO: Filtros para categorías de riesgo y comercio internacional
  def checkboxEstadoConservacion(explora_por=false)
    options = @nom_cites_iucn_todos.map{ |k,v| [t(k), v.map{ |val| [val.descripcion, val.id, { class: "#{val.descripcion.estandariza}-ev-icon f-fuentes" }] }] }
    select_tag('edo_cons', grouped_options_for_select(options), { class: 'selectpicker form-control form-group', 'data-live-search-normalize': true, 'data-live-search': true, 'data-selected-text-format': 'count > 1', 'data-select-all-text': 'Todos', 'data-deselect-all-text': 'Ninguno', 'data-actions-box': true, title: '- - Selecciona - -', multiple: true })
  end

  # REVISADO: Filtros para Tipos de distribuciónes en la busqueda avanzada
  def checkboxTipoDistribucion
    checkBoxes = ''

    if I18n.locale.to_s == 'es-cientifico'
      @distribuciones.each do |tipoDist|
        checkBoxes << "<label>"
        checkBoxes << check_box_tag('dist[]', tipoDist.id, false, id: "dist_#{tipoDist.id}")
        checkBoxes << "<span title = '#{t('distribucion.' << tipoDist.descripcion.estandariza)}' class='btn btn-xs btn-basica '>#{tipoDist.descripcion}</span>"
        checkBoxes << "</label>"
      end
    else
      @distribuciones.each do |tipoDist|
        checkBoxes << "<label>"
        checkBoxes << check_box_tag('dist[]', tipoDist.id, false, id: "dist_#{tipoDist.id}")
        checkBoxes << "<span title = '#{tipoDist.descripcion}' class = 'btn btn-xs btn-basica btn-title'>"
        checkBoxes << "<i class = '#{tipoDist.descripcion.estandariza}-ev-icon'></i>"
        checkBoxes << "</span>"
        checkBoxes << "</label>"
      end
    end

    checkBoxes
  end

  # REVISADO: Filtros para Especies prioritarias para la conservación en la busqueda avanzada
  def checkboxPrioritaria
    checkBoxes = ''

    @prioritarias.each do |prior|
      checkBoxes << '<label>'
      checkBoxes << check_box_tag('prior[]', prior.id, false, :id => "prior_#{prior.id}")
      checkBoxes << "<span title = 'Prioritaria con grado #{prior.descripcion.estandariza}' class = 'btn btn-xs btn-basica btn-title' >"
      checkBoxes << "<i class = '#{prior.descripcion.estandariza}-ev-icon'></i>"
      checkBoxes << '</span>'
      checkBoxes << '</label>'
    end

    checkBoxes
  end

  # REVISADO: Filtros para estatus taxonómico en la busqueda avanzada
  def checkboxValidoSinonimo (busqueda=nil)
    checkBoxes = ''

    Especie::ESTATUS_BUSQUEDA.each do |e|
      checkBoxes += case busqueda
                    when "BBShow" then "<label class='checkbox-inline'>#{check_box_tag('estatus[]', e.first, false, :class => :busqueda_atributo_checkbox, :onChange => '$(".checkBoxesOcultos").empty();$("#panelValidoSinonimoBasica  :checked ").attr("checked",true).clone().appendTo(".checkBoxesOcultos");')} #{e.last}</label>"
                    else "<label> #{check_box_tag('estatus[]', e.first, false, id: "estatus_#{e.first}")} <span class = 'btn btn-xs btn-basica' title = #{e.last}>#{e.last}</span></label>"
                    end
    end
    checkBoxes
  end

  # Si la búsqueda ya fue realizada y se desea generar un checklist, unicamente se añade un parametro extra y se realiza la búsqueda as usual
  def checklist(datos)
    if datos[:totales] > 0
      sin_page_per_page = datos[:request].split('&').map{|attr| attr if !attr.include?('pagina=')}
      peticion = sin_page_per_page.compact.join('&')
      peticion << "&por_pagina=#{datos[:totales]}&checklist=1"
    else
      ''
    end
  end
end
