class Busqueda
  attr_accessor :params, :taxones, :totales, :por_categoria, :es_cientifico, :original_url

  POR_PAGINA = [50, 100, 200]
  POR_PAGINA_PREDETERMINADO = POR_PAGINA.first

  NIVEL_CATEGORIAS_HASH = {
      '>' => 'inferiores a',
      '>=' => 'inferiores o iguales a',
      '=' => 'iguales a',
      '<=' => 'superiores o iguales a',
      '<' => 'superiores a'
  }

  NIVEL_CATEGORIAS = [
      ['inferior o igual a', '>='],
      ['inferior a', '>'],
      ['igual a', '='],
      ['superior o igual a', '<='],
      ['superior a', '<']
  ]

  GRUPOS_REINOS = %w(Animalia Plantae Fungi Prokaryotae Protoctista)
  GRUPOS_ANIMALES = %w(Mammalia Aves Reptilia Amphibia Actinopterygii Petromyzontidae Myxini Chondrichthyes Cnidaria Arachnida Myriapoda Annelida Insecta Porifera Echinodermata Mollusca Crustacea)
  GRUPOS_PLANTAS = %w(Bryophyta Pteridophyta Cycadophyta Gnetophyta Liliopsida Coniferophyta Magnoliopsida)

  # REVISADO: Inicializa los objetos busqueda
  def initialize
    self.taxones = Especie.left_joins(:categoria_taxonomica, :adicional)
    self.totales = 0
  end

  # REVISADO: Regresa la busqueda avanzada
  def avanzada
    # Para el paginado
    pagina = params[:pagina].present? ? params[:pagina].to_i : 1
    por_pagina = params[:por_pagina].present? ? params[:por_pagina].to_i : POR_PAGINA_PREDETERMINADO
    offset = (pagina-1)*por_pagina

    # Parte de la categoria taxonomica
    if params[:id].present? && params[:cat].present? && params[:nivel].present?
      begin
        taxon = Especie.find(params[:id])
      rescue
        self.taxones = Especie.none
        return
      end

      # Aplica el query para los descendientes
      self.taxones = taxones.where("#{Especie.attribute_alias(:ancestry_ascendente_directo)} LIKE '%,#{taxon.id},%'")

      # Se limita la busqueda al rango de categorias taxonomicas de acuerdo al nivel
      self.taxones = taxones.nivel_categoria(params[:nivel], params[:cat])
    end

    # Parte del estatus
    if es_cientifico
      self.taxones = taxones.where(estatus: params[:estatus]) if params[:estatus].present? && params[:estatus].length > 0
    else  # En la busqueda general solo el valido
      self.taxones = taxones.where(estatus: 2)
    end

    # Asocia el tipo de distribucion, categoria de riesgo y grado de prioridad
    filtros_compartidos

    # Solo la categoria que escogi, en caso de haber escogido una pestaña en busqueda avanzada
    if params[:solo_categoria]
      self.taxones = taxones.where(CategoriaTaxonomica.attribute_alias(:id) => params[:solo_categoria])
    end

    # Por si carga la pagina de un inicio, /busquedas/resultados
    if pagina == 1 && params[:solo_categoria].blank?
      # Para sacar los resultados por categoria
      por_categoria_taxonomica

      # Los totales del query
      self.totales = taxones.count
    end

    if params[:checklist] == '1'
      self.taxones = taxones.datos_arbol_con_filtros
      checklist
    else
      self.taxones = taxones.select_basico.order(:nombre_cientifico).offset(offset).limit(por_pagina).distinct

      # Si solo escribio un nombre
      if params[:id].blank? && params[:nombre].present?
        self.taxones = taxones.caso_nombre_comun_y_cientifico(params[:nombre].limpia_sql).left_joins(:nombres_comunes)

        taxones.each do |t|
          t.cual_nombre_comun_coincidio(params[:nombre])
        end
      end
    end

  end

  # REVISADO: Asocia el tipo de distribucion, categoria de riesgo y grado de prioridad
  def filtros_compartidos
    # Parte del tipo de ditribucion
    if params[:dist].present? && params[:dist].any?
      self.taxones = taxones.where("#{TipoDistribucion.table_name}.#{TipoDistribucion.attribute_alias(:id)} IN (?)", params[:dist]).left_joins(:tipos_distribuciones)
    end

    # Parte del edo. de conservacion y el nivel de prioritaria
    if params[:edo_cons].present? || params[:prior].present?
      catalogos = (params[:edo_cons] || []) + (params[:prior] || [])
      self.taxones = taxones.where("#{Catalogo.table_name}.#{Catalogo.attribute_alias(:id)} IN (?)", catalogos).left_joins(:catalogos)
    end
  end

  def por_categoria_taxonomica
    por_categoria = taxones.
        select(:categoria_taxonomica_id, "#{CategoriaTaxonomica.attribute_alias(:nombre_categoria_taxonomica)} AS nombre_categoria_taxonomica, COUNT(DISTINCT #{Especie.table_name}.#{Especie.attribute_alias(:id)}) AS cuantos").
        group(:categoria_taxonomica_id, CategoriaTaxonomica.attribute_alias(:nombre_categoria_taxonomica)).
        order(CategoriaTaxonomica.attribute_alias(:nombre_categoria_taxonomica))

    self.por_categoria = por_categoria.map{|cat| {nombre_categoria_taxonomica: cat.nombre_categoria_taxonomica,
                                                  cuantos: cat.cuantos, url: "#{original_url}&solo_categoria=#{cat.categoria_taxonomica_id}",
                                                  categoria_taxonomica_id: cat.categoria_taxonomica_id}}
  end

  # Este UNION fue necesario, ya que hacerlo en uno solo, los contains llevan mucho mucho tiempo
  def self.por_categoria_busqueda_basica(nombre, opts={})
    campos = %w(nombre_comun nombre_cientifico nombre_comun_principal)
    union = []

    campos.each do |c|
      subquery = "SELECT nombre_categoria_taxonomica AS nom,especies.id AS esp
 FROM especies
 LEFT JOIN categorias_taxonomicas ON categorias_taxonomicas.id=especies.categoria_taxonomica_id
 LEFT JOIN adicionales ON adicionales.especie_id=especies.id
 LEFT JOIN nombres_regiones ON nombres_regiones.especie_id=especies.id
 LEFT JOIN nombres_comunes ON nombres_comunes.id=nombres_regiones.nombre_comun_id
 WHERE CONTAINS(#{c}, '\"#{nombre.limpia_sql}*\"')"

      if opts[:vista_general]
        subquery << ' AND estatus=2'
      end

      union << subquery
    end

    query = 'SELECT nom AS nombre_categoria_taxonomica, count(esp) AS cuantos FROM (' + union.join(' UNION ') + ') especies GROUP BY nom ORDER BY nom ASC'

    Especie.find_by_sql(query).map{|t| {nombre_categoria_taxonomica: t.nombre_categoria_taxonomica,
                                        cuantos: t.cuantos, url: "#{opts[:original_url]}&solo_categoria=#{I18n.transliterate(t.nombre_categoria_taxonomica).downcase.gsub(' ','_')}"}}
  end

  # Este UNION fue necesario, ya que hacerlo en uno solo, los contains llevan mucho mucho tiempo
  def self.basica(nombre, opts={})
    campos = %w(nombre_comun nombre_cientifico nombre_comun_principal)
    union = []

    select = 'SELECT DISTINCT especies.id, nombre_cientifico, estatus, nombre_autoridad,
adicionales.nombre_comun_principal, adicionales.foto_principal,
categoria_taxonomica_id, categorias_taxonomicas.nombre_categoria_taxonomica, ancestry_ascendente_directo,
cita_nomenclatural, nombres_comunes as nombres_comunes_adicionales FROM ( '

    from = ') especies
 LEFT JOIN categorias_taxonomicas ON categorias_taxonomicas.id=especies.categoria_taxonomica_id
 LEFT JOIN adicionales ON adicionales.especie_id=especies.id
 LEFT JOIN nombres_regiones ON nombres_regiones.especie_id=especies.id
 LEFT JOIN nombres_comunes ON nombres_comunes.id=nombres_regiones.nombre_comun_id
 ORDER BY nombre_cientifico ASC'

    if opts[:todos].blank? && opts[:pagina].present? && opts[:por_pagina].present?
      from << " OFFSET #{(opts[:pagina]-1)*opts[:por_pagina]} ROWS FETCH NEXT #{opts[:por_pagina]} ROWS ONLY"
    end

    campos.each do |c|
      subquery = "SELECT especies.id, nombre_cientifico, estatus, nombre_autoridad,
 adicionales.nombre_comun_principal, adicionales.foto_principal,
 categoria_taxonomica_id, nombre_categoria_taxonomica, ancestry_ascendente_directo,
 cita_nomenclatural, nombres_comunes as nombres_comunes_adicionales
 FROM especies
 LEFT JOIN categorias_taxonomicas ON categorias_taxonomicas.id=especies.categoria_taxonomica_id
 LEFT JOIN adicionales ON adicionales.especie_id=especies.id
 LEFT JOIN nombres_regiones ON nombres_regiones.especie_id=especies.id
 LEFT JOIN nombres_comunes ON nombres_comunes.id=nombres_regiones.nombre_comun_id
 WHERE CONTAINS(#{c}, '\"#{nombre.limpia_sql}*\"')"

      if opts[:vista_general]
        subquery << ' AND estatus=2'
      end

      if opts[:solo_categoria].present?
        subquery << " AND nombre_categoria_taxonomica='#{opts[:solo_categoria]}' COLLATE Latin1_general_CI_AI"
      end

      union << subquery
    end

    query = select + union.join(' UNION ') + from
    Especie.find_by_sql(query)
  end

  # Este UNION fue necesario, ya que hacerlo en uno solo, los contains llevan mucho mucho tiempo
  def self.count_basica(nombre, opts={})
    campos = %w(nombre_comun nombre_cientifico nombre_comun_principal)
    union = []

    campos.each do |c|
      subquery = " SELECT especies.id AS esp
FROM especies
LEFT JOIN categorias_taxonomicas ON categorias_taxonomicas.id=especies.categoria_taxonomica_id
LEFT JOIN adicionales ON adicionales.especie_id=especies.id
LEFT JOIN nombres_regiones ON nombres_regiones.especie_id=especies.id
LEFT JOIN nombres_comunes ON nombres_comunes.id=nombres_regiones.nombre_comun_id
WHERE CONTAINS(#{c}, '\"#{nombre.limpia_sql}*\"')"

      if opts[:vista_general]
        subquery << ' AND estatus=2'
      end

      if opts[:solo_categoria].present?
        subquery << " AND nombre_categoria_taxonomica='#{opts[:solo_categoria]}' COLLATE Latin1_general_CI_AI"
      end

      union << subquery
    end

    query = 'SELECT COUNT(DISTINCT esp) AS totales FROM (' + union.join(' UNION ') + ') AS suma'
    res = Especie.find_by_sql(query)
    res[0].totales
  end

  def self.asigna_grupo_iconico
    # Itera los grupos y algunos reinos
    animalia_plantae = %w(Animalia Plantae)
    complemento_reinos = %w(Protoctista Fungi Prokaryotae)
    iconos_plantae = %w(Bryophyta Pteridophyta Cycadophyta Gnetophyta Liliopsida Coniferophyta Magnoliopsida)

    Icono.all.map{|ic| [ic.id, ic.taxon_icono]}.each do |id, grupo|
      puts grupo
      ad = Adicional.none
      taxon = Especie.where(:nombre_cientifico => grupo).first
      puts "Hubo un error al buscar el taxon: #{grupo}" unless taxon

      # solo animalia y plantae
      if animalia_plantae.include?(grupo)
        if ad = taxon.adicional
          ad.icono_id = id
        else
          ad = taxon.crea_con_grupo_iconico(id)
        end

      else  # Los grupos y reinos menos animalia y plantae
        nivel = iconos_plantae.include?(grupo) ? 3000 : 3100
        descendientes = taxon.subtree_ids

        # Itero sobre los descendientes
        descendientes.each do |descendiente|
          begin
            taxon_desc = Especie.find(descendiente)
          rescue
            next
          end

          puts "\tDescendiente de #{grupo}: #{taxon_desc.nombre_cientifico}"

          if !complemento_reinos.include?(grupo)
            # No poner icono inferiores de clase
            clase_desc = taxon_desc.categoria_taxonomica
            nivel_desc = "#{clase_desc.nivel1}#{clase_desc.nivel2}#{clase_desc.nivel3}#{clase_desc.nivel4}".to_i
            puts "\t\t#{nivel_desc > nivel ? 'Inferior a clase' : 'Superior a clase'}"
            next if nivel_desc > nivel
          end

          if ad = taxon_desc.adicional
            ad.icono_id = id
          else
            ad = taxon_desc.crea_con_grupo_iconico(id)
          end

          # Guarda el record
          ad.save if ad.changed?

        end  # Cierra el each de descendientes
      end

      # Por si no estaba definido cuando termino el loop
      next unless ad.present?

      # Guarda el record
      ad.save if ad.changed?

    end  # Cierra el iterador de grupos
  end
end
