// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $CachedCategoriesTable extends CachedCategories
    with TableInfo<$CachedCategoriesTable, CachedCategory> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CachedCategoriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sortOrderMeta = const VerificationMeta(
    'sortOrder',
  );
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
    'sort_order',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _imageUrlMeta = const VerificationMeta(
    'imageUrl',
  );
  @override
  late final GeneratedColumn<String> imageUrl = GeneratedColumn<String>(
    'image_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [id, name, sortOrder, imageUrl];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'cached_categories';
  @override
  VerificationContext validateIntegrity(
    Insertable<CachedCategory> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
      );
    }
    if (data.containsKey('image_url')) {
      context.handle(
        _imageUrlMeta,
        imageUrl.isAcceptableOrUnknown(data['image_url']!, _imageUrlMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CachedCategory map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CachedCategory(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_order'],
      )!,
      imageUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}image_url'],
      ),
    );
  }

  @override
  $CachedCategoriesTable createAlias(String alias) {
    return $CachedCategoriesTable(attachedDatabase, alias);
  }
}

class CachedCategory extends DataClass implements Insertable<CachedCategory> {
  final String id;
  final String name;
  final int sortOrder;
  final String? imageUrl;
  const CachedCategory({
    required this.id,
    required this.name,
    required this.sortOrder,
    this.imageUrl,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['sort_order'] = Variable<int>(sortOrder);
    if (!nullToAbsent || imageUrl != null) {
      map['image_url'] = Variable<String>(imageUrl);
    }
    return map;
  }

  CachedCategoriesCompanion toCompanion(bool nullToAbsent) {
    return CachedCategoriesCompanion(
      id: Value(id),
      name: Value(name),
      sortOrder: Value(sortOrder),
      imageUrl: imageUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(imageUrl),
    );
  }

  factory CachedCategory.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CachedCategory(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
      imageUrl: serializer.fromJson<String?>(json['imageUrl']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'sortOrder': serializer.toJson<int>(sortOrder),
      'imageUrl': serializer.toJson<String?>(imageUrl),
    };
  }

  CachedCategory copyWith({
    String? id,
    String? name,
    int? sortOrder,
    Value<String?> imageUrl = const Value.absent(),
  }) => CachedCategory(
    id: id ?? this.id,
    name: name ?? this.name,
    sortOrder: sortOrder ?? this.sortOrder,
    imageUrl: imageUrl.present ? imageUrl.value : this.imageUrl,
  );
  CachedCategory copyWithCompanion(CachedCategoriesCompanion data) {
    return CachedCategory(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
      imageUrl: data.imageUrl.present ? data.imageUrl.value : this.imageUrl,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CachedCategory(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('imageUrl: $imageUrl')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, sortOrder, imageUrl);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CachedCategory &&
          other.id == this.id &&
          other.name == this.name &&
          other.sortOrder == this.sortOrder &&
          other.imageUrl == this.imageUrl);
}

class CachedCategoriesCompanion extends UpdateCompanion<CachedCategory> {
  final Value<String> id;
  final Value<String> name;
  final Value<int> sortOrder;
  final Value<String?> imageUrl;
  final Value<int> rowid;
  const CachedCategoriesCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.imageUrl = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CachedCategoriesCompanion.insert({
    required String id,
    required String name,
    this.sortOrder = const Value.absent(),
    this.imageUrl = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name);
  static Insertable<CachedCategory> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<int>? sortOrder,
    Expression<String>? imageUrl,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (imageUrl != null) 'image_url': imageUrl,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CachedCategoriesCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<int>? sortOrder,
    Value<String?>? imageUrl,
    Value<int>? rowid,
  }) {
    return CachedCategoriesCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      sortOrder: sortOrder ?? this.sortOrder,
      imageUrl: imageUrl ?? this.imageUrl,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (imageUrl.present) {
      map['image_url'] = Variable<String>(imageUrl.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CachedCategoriesCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('imageUrl: $imageUrl, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CachedProductsTable extends CachedProducts
    with TableInfo<$CachedProductsTable, CachedProduct> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CachedProductsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _categoryIdMeta = const VerificationMeta(
    'categoryId',
  );
  @override
  late final GeneratedColumn<String> categoryId = GeneratedColumn<String>(
    'category_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _skuMeta = const VerificationMeta('sku');
  @override
  late final GeneratedColumn<String> sku = GeneratedColumn<String>(
    'sku',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _priceMeta = const VerificationMeta('price');
  @override
  late final GeneratedColumn<double> price = GeneratedColumn<double>(
    'price',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _mxikCodeMeta = const VerificationMeta(
    'mxikCode',
  );
  @override
  late final GeneratedColumn<String> mxikCode = GeneratedColumn<String>(
    'mxik_code',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _packageCodeMeta = const VerificationMeta(
    'packageCode',
  );
  @override
  late final GeneratedColumn<String> packageCode = GeneratedColumn<String>(
    'package_code',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _vatPercentMeta = const VerificationMeta(
    'vatPercent',
  );
  @override
  late final GeneratedColumn<double> vatPercent = GeneratedColumn<double>(
    'vat_percent',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(12),
  );
  static const VerificationMeta _unitMeta = const VerificationMeta('unit');
  @override
  late final GeneratedColumn<String> unit = GeneratedColumn<String>(
    'unit',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('dona'),
  );
  static const VerificationMeta _imageUrlMeta = const VerificationMeta(
    'imageUrl',
  );
  @override
  late final GeneratedColumn<String> imageUrl = GeneratedColumn<String>(
    'image_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _isActiveMeta = const VerificationMeta(
    'isActive',
  );
  @override
  late final GeneratedColumn<bool> isActive = GeneratedColumn<bool>(
    'is_active',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_active" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _markingRequiredMeta = const VerificationMeta(
    'markingRequired',
  );
  @override
  late final GeneratedColumn<bool> markingRequired = GeneratedColumn<bool>(
    'marking_required',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("marking_required" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _trackStockMeta = const VerificationMeta(
    'trackStock',
  );
  @override
  late final GeneratedColumn<bool> trackStock = GeneratedColumn<bool>(
    'track_stock',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("track_stock" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _stockQtyMeta = const VerificationMeta(
    'stockQty',
  );
  @override
  late final GeneratedColumn<double> stockQty = GeneratedColumn<double>(
    'stock_qty',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _lowStockThresholdMeta = const VerificationMeta(
    'lowStockThreshold',
  );
  @override
  late final GeneratedColumn<double> lowStockThreshold =
      GeneratedColumn<double>(
        'low_stock_threshold',
        aliasedName,
        false,
        type: DriftSqlType.double,
        requiredDuringInsert: false,
        defaultValue: const Constant(10),
      );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    categoryId,
    name,
    sku,
    price,
    mxikCode,
    packageCode,
    vatPercent,
    unit,
    imageUrl,
    isActive,
    markingRequired,
    trackStock,
    stockQty,
    lowStockThreshold,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'cached_products';
  @override
  VerificationContext validateIntegrity(
    Insertable<CachedProduct> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('category_id')) {
      context.handle(
        _categoryIdMeta,
        categoryId.isAcceptableOrUnknown(data['category_id']!, _categoryIdMeta),
      );
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('sku')) {
      context.handle(
        _skuMeta,
        sku.isAcceptableOrUnknown(data['sku']!, _skuMeta),
      );
    }
    if (data.containsKey('price')) {
      context.handle(
        _priceMeta,
        price.isAcceptableOrUnknown(data['price']!, _priceMeta),
      );
    }
    if (data.containsKey('mxik_code')) {
      context.handle(
        _mxikCodeMeta,
        mxikCode.isAcceptableOrUnknown(data['mxik_code']!, _mxikCodeMeta),
      );
    }
    if (data.containsKey('package_code')) {
      context.handle(
        _packageCodeMeta,
        packageCode.isAcceptableOrUnknown(
          data['package_code']!,
          _packageCodeMeta,
        ),
      );
    }
    if (data.containsKey('vat_percent')) {
      context.handle(
        _vatPercentMeta,
        vatPercent.isAcceptableOrUnknown(data['vat_percent']!, _vatPercentMeta),
      );
    }
    if (data.containsKey('unit')) {
      context.handle(
        _unitMeta,
        unit.isAcceptableOrUnknown(data['unit']!, _unitMeta),
      );
    }
    if (data.containsKey('image_url')) {
      context.handle(
        _imageUrlMeta,
        imageUrl.isAcceptableOrUnknown(data['image_url']!, _imageUrlMeta),
      );
    }
    if (data.containsKey('is_active')) {
      context.handle(
        _isActiveMeta,
        isActive.isAcceptableOrUnknown(data['is_active']!, _isActiveMeta),
      );
    }
    if (data.containsKey('marking_required')) {
      context.handle(
        _markingRequiredMeta,
        markingRequired.isAcceptableOrUnknown(
          data['marking_required']!,
          _markingRequiredMeta,
        ),
      );
    }
    if (data.containsKey('track_stock')) {
      context.handle(
        _trackStockMeta,
        trackStock.isAcceptableOrUnknown(data['track_stock']!, _trackStockMeta),
      );
    }
    if (data.containsKey('stock_qty')) {
      context.handle(
        _stockQtyMeta,
        stockQty.isAcceptableOrUnknown(data['stock_qty']!, _stockQtyMeta),
      );
    }
    if (data.containsKey('low_stock_threshold')) {
      context.handle(
        _lowStockThresholdMeta,
        lowStockThreshold.isAcceptableOrUnknown(
          data['low_stock_threshold']!,
          _lowStockThresholdMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CachedProduct map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CachedProduct(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      categoryId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}category_id'],
      ),
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      sku: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sku'],
      ),
      price: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}price'],
      )!,
      mxikCode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}mxik_code'],
      ),
      packageCode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}package_code'],
      ),
      vatPercent: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}vat_percent'],
      )!,
      unit: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}unit'],
      )!,
      imageUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}image_url'],
      ),
      isActive: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_active'],
      )!,
      markingRequired: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}marking_required'],
      )!,
      trackStock: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}track_stock'],
      )!,
      stockQty: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}stock_qty'],
      )!,
      lowStockThreshold: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}low_stock_threshold'],
      )!,
    );
  }

  @override
  $CachedProductsTable createAlias(String alias) {
    return $CachedProductsTable(attachedDatabase, alias);
  }
}

class CachedProduct extends DataClass implements Insertable<CachedProduct> {
  final String id;
  final String? categoryId;
  final String name;
  final String? sku;
  final double price;
  final String? mxikCode;
  final String? packageCode;
  final double vatPercent;
  final String unit;
  final String? imageUrl;
  final bool isActive;
  final bool markingRequired;
  final bool trackStock;
  final double stockQty;
  final double lowStockThreshold;
  const CachedProduct({
    required this.id,
    this.categoryId,
    required this.name,
    this.sku,
    required this.price,
    this.mxikCode,
    this.packageCode,
    required this.vatPercent,
    required this.unit,
    this.imageUrl,
    required this.isActive,
    required this.markingRequired,
    required this.trackStock,
    required this.stockQty,
    required this.lowStockThreshold,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    if (!nullToAbsent || categoryId != null) {
      map['category_id'] = Variable<String>(categoryId);
    }
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || sku != null) {
      map['sku'] = Variable<String>(sku);
    }
    map['price'] = Variable<double>(price);
    if (!nullToAbsent || mxikCode != null) {
      map['mxik_code'] = Variable<String>(mxikCode);
    }
    if (!nullToAbsent || packageCode != null) {
      map['package_code'] = Variable<String>(packageCode);
    }
    map['vat_percent'] = Variable<double>(vatPercent);
    map['unit'] = Variable<String>(unit);
    if (!nullToAbsent || imageUrl != null) {
      map['image_url'] = Variable<String>(imageUrl);
    }
    map['is_active'] = Variable<bool>(isActive);
    map['marking_required'] = Variable<bool>(markingRequired);
    map['track_stock'] = Variable<bool>(trackStock);
    map['stock_qty'] = Variable<double>(stockQty);
    map['low_stock_threshold'] = Variable<double>(lowStockThreshold);
    return map;
  }

  CachedProductsCompanion toCompanion(bool nullToAbsent) {
    return CachedProductsCompanion(
      id: Value(id),
      categoryId: categoryId == null && nullToAbsent
          ? const Value.absent()
          : Value(categoryId),
      name: Value(name),
      sku: sku == null && nullToAbsent ? const Value.absent() : Value(sku),
      price: Value(price),
      mxikCode: mxikCode == null && nullToAbsent
          ? const Value.absent()
          : Value(mxikCode),
      packageCode: packageCode == null && nullToAbsent
          ? const Value.absent()
          : Value(packageCode),
      vatPercent: Value(vatPercent),
      unit: Value(unit),
      imageUrl: imageUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(imageUrl),
      isActive: Value(isActive),
      markingRequired: Value(markingRequired),
      trackStock: Value(trackStock),
      stockQty: Value(stockQty),
      lowStockThreshold: Value(lowStockThreshold),
    );
  }

  factory CachedProduct.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CachedProduct(
      id: serializer.fromJson<String>(json['id']),
      categoryId: serializer.fromJson<String?>(json['categoryId']),
      name: serializer.fromJson<String>(json['name']),
      sku: serializer.fromJson<String?>(json['sku']),
      price: serializer.fromJson<double>(json['price']),
      mxikCode: serializer.fromJson<String?>(json['mxikCode']),
      packageCode: serializer.fromJson<String?>(json['packageCode']),
      vatPercent: serializer.fromJson<double>(json['vatPercent']),
      unit: serializer.fromJson<String>(json['unit']),
      imageUrl: serializer.fromJson<String?>(json['imageUrl']),
      isActive: serializer.fromJson<bool>(json['isActive']),
      markingRequired: serializer.fromJson<bool>(json['markingRequired']),
      trackStock: serializer.fromJson<bool>(json['trackStock']),
      stockQty: serializer.fromJson<double>(json['stockQty']),
      lowStockThreshold: serializer.fromJson<double>(json['lowStockThreshold']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'categoryId': serializer.toJson<String?>(categoryId),
      'name': serializer.toJson<String>(name),
      'sku': serializer.toJson<String?>(sku),
      'price': serializer.toJson<double>(price),
      'mxikCode': serializer.toJson<String?>(mxikCode),
      'packageCode': serializer.toJson<String?>(packageCode),
      'vatPercent': serializer.toJson<double>(vatPercent),
      'unit': serializer.toJson<String>(unit),
      'imageUrl': serializer.toJson<String?>(imageUrl),
      'isActive': serializer.toJson<bool>(isActive),
      'markingRequired': serializer.toJson<bool>(markingRequired),
      'trackStock': serializer.toJson<bool>(trackStock),
      'stockQty': serializer.toJson<double>(stockQty),
      'lowStockThreshold': serializer.toJson<double>(lowStockThreshold),
    };
  }

  CachedProduct copyWith({
    String? id,
    Value<String?> categoryId = const Value.absent(),
    String? name,
    Value<String?> sku = const Value.absent(),
    double? price,
    Value<String?> mxikCode = const Value.absent(),
    Value<String?> packageCode = const Value.absent(),
    double? vatPercent,
    String? unit,
    Value<String?> imageUrl = const Value.absent(),
    bool? isActive,
    bool? markingRequired,
    bool? trackStock,
    double? stockQty,
    double? lowStockThreshold,
  }) => CachedProduct(
    id: id ?? this.id,
    categoryId: categoryId.present ? categoryId.value : this.categoryId,
    name: name ?? this.name,
    sku: sku.present ? sku.value : this.sku,
    price: price ?? this.price,
    mxikCode: mxikCode.present ? mxikCode.value : this.mxikCode,
    packageCode: packageCode.present ? packageCode.value : this.packageCode,
    vatPercent: vatPercent ?? this.vatPercent,
    unit: unit ?? this.unit,
    imageUrl: imageUrl.present ? imageUrl.value : this.imageUrl,
    isActive: isActive ?? this.isActive,
    markingRequired: markingRequired ?? this.markingRequired,
    trackStock: trackStock ?? this.trackStock,
    stockQty: stockQty ?? this.stockQty,
    lowStockThreshold: lowStockThreshold ?? this.lowStockThreshold,
  );
  CachedProduct copyWithCompanion(CachedProductsCompanion data) {
    return CachedProduct(
      id: data.id.present ? data.id.value : this.id,
      categoryId: data.categoryId.present
          ? data.categoryId.value
          : this.categoryId,
      name: data.name.present ? data.name.value : this.name,
      sku: data.sku.present ? data.sku.value : this.sku,
      price: data.price.present ? data.price.value : this.price,
      mxikCode: data.mxikCode.present ? data.mxikCode.value : this.mxikCode,
      packageCode: data.packageCode.present
          ? data.packageCode.value
          : this.packageCode,
      vatPercent: data.vatPercent.present
          ? data.vatPercent.value
          : this.vatPercent,
      unit: data.unit.present ? data.unit.value : this.unit,
      imageUrl: data.imageUrl.present ? data.imageUrl.value : this.imageUrl,
      isActive: data.isActive.present ? data.isActive.value : this.isActive,
      markingRequired: data.markingRequired.present
          ? data.markingRequired.value
          : this.markingRequired,
      trackStock: data.trackStock.present
          ? data.trackStock.value
          : this.trackStock,
      stockQty: data.stockQty.present ? data.stockQty.value : this.stockQty,
      lowStockThreshold: data.lowStockThreshold.present
          ? data.lowStockThreshold.value
          : this.lowStockThreshold,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CachedProduct(')
          ..write('id: $id, ')
          ..write('categoryId: $categoryId, ')
          ..write('name: $name, ')
          ..write('sku: $sku, ')
          ..write('price: $price, ')
          ..write('mxikCode: $mxikCode, ')
          ..write('packageCode: $packageCode, ')
          ..write('vatPercent: $vatPercent, ')
          ..write('unit: $unit, ')
          ..write('imageUrl: $imageUrl, ')
          ..write('isActive: $isActive, ')
          ..write('markingRequired: $markingRequired, ')
          ..write('trackStock: $trackStock, ')
          ..write('stockQty: $stockQty, ')
          ..write('lowStockThreshold: $lowStockThreshold')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    categoryId,
    name,
    sku,
    price,
    mxikCode,
    packageCode,
    vatPercent,
    unit,
    imageUrl,
    isActive,
    markingRequired,
    trackStock,
    stockQty,
    lowStockThreshold,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CachedProduct &&
          other.id == this.id &&
          other.categoryId == this.categoryId &&
          other.name == this.name &&
          other.sku == this.sku &&
          other.price == this.price &&
          other.mxikCode == this.mxikCode &&
          other.packageCode == this.packageCode &&
          other.vatPercent == this.vatPercent &&
          other.unit == this.unit &&
          other.imageUrl == this.imageUrl &&
          other.isActive == this.isActive &&
          other.markingRequired == this.markingRequired &&
          other.trackStock == this.trackStock &&
          other.stockQty == this.stockQty &&
          other.lowStockThreshold == this.lowStockThreshold);
}

class CachedProductsCompanion extends UpdateCompanion<CachedProduct> {
  final Value<String> id;
  final Value<String?> categoryId;
  final Value<String> name;
  final Value<String?> sku;
  final Value<double> price;
  final Value<String?> mxikCode;
  final Value<String?> packageCode;
  final Value<double> vatPercent;
  final Value<String> unit;
  final Value<String?> imageUrl;
  final Value<bool> isActive;
  final Value<bool> markingRequired;
  final Value<bool> trackStock;
  final Value<double> stockQty;
  final Value<double> lowStockThreshold;
  final Value<int> rowid;
  const CachedProductsCompanion({
    this.id = const Value.absent(),
    this.categoryId = const Value.absent(),
    this.name = const Value.absent(),
    this.sku = const Value.absent(),
    this.price = const Value.absent(),
    this.mxikCode = const Value.absent(),
    this.packageCode = const Value.absent(),
    this.vatPercent = const Value.absent(),
    this.unit = const Value.absent(),
    this.imageUrl = const Value.absent(),
    this.isActive = const Value.absent(),
    this.markingRequired = const Value.absent(),
    this.trackStock = const Value.absent(),
    this.stockQty = const Value.absent(),
    this.lowStockThreshold = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CachedProductsCompanion.insert({
    required String id,
    this.categoryId = const Value.absent(),
    required String name,
    this.sku = const Value.absent(),
    this.price = const Value.absent(),
    this.mxikCode = const Value.absent(),
    this.packageCode = const Value.absent(),
    this.vatPercent = const Value.absent(),
    this.unit = const Value.absent(),
    this.imageUrl = const Value.absent(),
    this.isActive = const Value.absent(),
    this.markingRequired = const Value.absent(),
    this.trackStock = const Value.absent(),
    this.stockQty = const Value.absent(),
    this.lowStockThreshold = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name);
  static Insertable<CachedProduct> custom({
    Expression<String>? id,
    Expression<String>? categoryId,
    Expression<String>? name,
    Expression<String>? sku,
    Expression<double>? price,
    Expression<String>? mxikCode,
    Expression<String>? packageCode,
    Expression<double>? vatPercent,
    Expression<String>? unit,
    Expression<String>? imageUrl,
    Expression<bool>? isActive,
    Expression<bool>? markingRequired,
    Expression<bool>? trackStock,
    Expression<double>? stockQty,
    Expression<double>? lowStockThreshold,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (categoryId != null) 'category_id': categoryId,
      if (name != null) 'name': name,
      if (sku != null) 'sku': sku,
      if (price != null) 'price': price,
      if (mxikCode != null) 'mxik_code': mxikCode,
      if (packageCode != null) 'package_code': packageCode,
      if (vatPercent != null) 'vat_percent': vatPercent,
      if (unit != null) 'unit': unit,
      if (imageUrl != null) 'image_url': imageUrl,
      if (isActive != null) 'is_active': isActive,
      if (markingRequired != null) 'marking_required': markingRequired,
      if (trackStock != null) 'track_stock': trackStock,
      if (stockQty != null) 'stock_qty': stockQty,
      if (lowStockThreshold != null) 'low_stock_threshold': lowStockThreshold,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CachedProductsCompanion copyWith({
    Value<String>? id,
    Value<String?>? categoryId,
    Value<String>? name,
    Value<String?>? sku,
    Value<double>? price,
    Value<String?>? mxikCode,
    Value<String?>? packageCode,
    Value<double>? vatPercent,
    Value<String>? unit,
    Value<String?>? imageUrl,
    Value<bool>? isActive,
    Value<bool>? markingRequired,
    Value<bool>? trackStock,
    Value<double>? stockQty,
    Value<double>? lowStockThreshold,
    Value<int>? rowid,
  }) {
    return CachedProductsCompanion(
      id: id ?? this.id,
      categoryId: categoryId ?? this.categoryId,
      name: name ?? this.name,
      sku: sku ?? this.sku,
      price: price ?? this.price,
      mxikCode: mxikCode ?? this.mxikCode,
      packageCode: packageCode ?? this.packageCode,
      vatPercent: vatPercent ?? this.vatPercent,
      unit: unit ?? this.unit,
      imageUrl: imageUrl ?? this.imageUrl,
      isActive: isActive ?? this.isActive,
      markingRequired: markingRequired ?? this.markingRequired,
      trackStock: trackStock ?? this.trackStock,
      stockQty: stockQty ?? this.stockQty,
      lowStockThreshold: lowStockThreshold ?? this.lowStockThreshold,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (categoryId.present) {
      map['category_id'] = Variable<String>(categoryId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (sku.present) {
      map['sku'] = Variable<String>(sku.value);
    }
    if (price.present) {
      map['price'] = Variable<double>(price.value);
    }
    if (mxikCode.present) {
      map['mxik_code'] = Variable<String>(mxikCode.value);
    }
    if (packageCode.present) {
      map['package_code'] = Variable<String>(packageCode.value);
    }
    if (vatPercent.present) {
      map['vat_percent'] = Variable<double>(vatPercent.value);
    }
    if (unit.present) {
      map['unit'] = Variable<String>(unit.value);
    }
    if (imageUrl.present) {
      map['image_url'] = Variable<String>(imageUrl.value);
    }
    if (isActive.present) {
      map['is_active'] = Variable<bool>(isActive.value);
    }
    if (markingRequired.present) {
      map['marking_required'] = Variable<bool>(markingRequired.value);
    }
    if (trackStock.present) {
      map['track_stock'] = Variable<bool>(trackStock.value);
    }
    if (stockQty.present) {
      map['stock_qty'] = Variable<double>(stockQty.value);
    }
    if (lowStockThreshold.present) {
      map['low_stock_threshold'] = Variable<double>(lowStockThreshold.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CachedProductsCompanion(')
          ..write('id: $id, ')
          ..write('categoryId: $categoryId, ')
          ..write('name: $name, ')
          ..write('sku: $sku, ')
          ..write('price: $price, ')
          ..write('mxikCode: $mxikCode, ')
          ..write('packageCode: $packageCode, ')
          ..write('vatPercent: $vatPercent, ')
          ..write('unit: $unit, ')
          ..write('imageUrl: $imageUrl, ')
          ..write('isActive: $isActive, ')
          ..write('markingRequired: $markingRequired, ')
          ..write('trackStock: $trackStock, ')
          ..write('stockQty: $stockQty, ')
          ..write('lowStockThreshold: $lowStockThreshold, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PendingOrdersTable extends PendingOrders
    with TableInfo<$PendingOrdersTable, PendingOrder> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PendingOrdersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _seqMeta = const VerificationMeta('seq');
  @override
  late final GeneratedColumn<int> seq = GeneratedColumn<int>(
    'seq',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _clientUuidMeta = const VerificationMeta(
    'clientUuid',
  );
  @override
  late final GeneratedColumn<String> clientUuid = GeneratedColumn<String>(
    'client_uuid',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _payloadJsonMeta = const VerificationMeta(
    'payloadJson',
  );
  @override
  late final GeneratedColumn<String> payloadJson = GeneratedColumn<String>(
    'payload_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _syncedMeta = const VerificationMeta('synced');
  @override
  late final GeneratedColumn<bool> synced = GeneratedColumn<bool>(
    'synced',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("synced" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _serverOrderIdMeta = const VerificationMeta(
    'serverOrderId',
  );
  @override
  late final GeneratedColumn<String> serverOrderId = GeneratedColumn<String>(
    'server_order_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _orderNumberMeta = const VerificationMeta(
    'orderNumber',
  );
  @override
  late final GeneratedColumn<String> orderNumber = GeneratedColumn<String>(
    'order_number',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _fiscalStatusMeta = const VerificationMeta(
    'fiscalStatus',
  );
  @override
  late final GeneratedColumn<String> fiscalStatus = GeneratedColumn<String>(
    'fiscal_status',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _fiscalQrUrlMeta = const VerificationMeta(
    'fiscalQrUrl',
  );
  @override
  late final GeneratedColumn<String> fiscalQrUrl = GeneratedColumn<String>(
    'fiscal_qr_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _totalMeta = const VerificationMeta('total');
  @override
  late final GeneratedColumn<int> total = GeneratedColumn<int>(
    'total',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _syncedAtMeta = const VerificationMeta(
    'syncedAt',
  );
  @override
  late final GeneratedColumn<DateTime> syncedAt = GeneratedColumn<DateTime>(
    'synced_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    seq,
    clientUuid,
    payloadJson,
    synced,
    serverOrderId,
    orderNumber,
    fiscalStatus,
    fiscalQrUrl,
    total,
    createdAt,
    syncedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'pending_orders';
  @override
  VerificationContext validateIntegrity(
    Insertable<PendingOrder> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('seq')) {
      context.handle(
        _seqMeta,
        seq.isAcceptableOrUnknown(data['seq']!, _seqMeta),
      );
    }
    if (data.containsKey('client_uuid')) {
      context.handle(
        _clientUuidMeta,
        clientUuid.isAcceptableOrUnknown(data['client_uuid']!, _clientUuidMeta),
      );
    } else if (isInserting) {
      context.missing(_clientUuidMeta);
    }
    if (data.containsKey('payload_json')) {
      context.handle(
        _payloadJsonMeta,
        payloadJson.isAcceptableOrUnknown(
          data['payload_json']!,
          _payloadJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_payloadJsonMeta);
    }
    if (data.containsKey('synced')) {
      context.handle(
        _syncedMeta,
        synced.isAcceptableOrUnknown(data['synced']!, _syncedMeta),
      );
    }
    if (data.containsKey('server_order_id')) {
      context.handle(
        _serverOrderIdMeta,
        serverOrderId.isAcceptableOrUnknown(
          data['server_order_id']!,
          _serverOrderIdMeta,
        ),
      );
    }
    if (data.containsKey('order_number')) {
      context.handle(
        _orderNumberMeta,
        orderNumber.isAcceptableOrUnknown(
          data['order_number']!,
          _orderNumberMeta,
        ),
      );
    }
    if (data.containsKey('fiscal_status')) {
      context.handle(
        _fiscalStatusMeta,
        fiscalStatus.isAcceptableOrUnknown(
          data['fiscal_status']!,
          _fiscalStatusMeta,
        ),
      );
    }
    if (data.containsKey('fiscal_qr_url')) {
      context.handle(
        _fiscalQrUrlMeta,
        fiscalQrUrl.isAcceptableOrUnknown(
          data['fiscal_qr_url']!,
          _fiscalQrUrlMeta,
        ),
      );
    }
    if (data.containsKey('total')) {
      context.handle(
        _totalMeta,
        total.isAcceptableOrUnknown(data['total']!, _totalMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('synced_at')) {
      context.handle(
        _syncedAtMeta,
        syncedAt.isAcceptableOrUnknown(data['synced_at']!, _syncedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {seq};
  @override
  PendingOrder map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PendingOrder(
      seq: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}seq'],
      )!,
      clientUuid: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}client_uuid'],
      )!,
      payloadJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload_json'],
      )!,
      synced: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}synced'],
      )!,
      serverOrderId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}server_order_id'],
      ),
      orderNumber: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}order_number'],
      ),
      fiscalStatus: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}fiscal_status'],
      ),
      fiscalQrUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}fiscal_qr_url'],
      ),
      total: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}total'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      syncedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}synced_at'],
      ),
    );
  }

  @override
  $PendingOrdersTable createAlias(String alias) {
    return $PendingOrdersTable(attachedDatabase, alias);
  }
}

class PendingOrder extends DataClass implements Insertable<PendingOrder> {
  /// Monotonic insertion sequence — gives a deterministic newest-first order
  /// even when several orders land within the same clock second.
  final int seq;

  /// uuid v4 — idempotency key shared with the backend.
  final String clientUuid;

  /// Full OrderIn JSON payload (items, payments, discount, table_no, note).
  final String payloadJson;

  /// Whether the backend has accepted this order.
  final bool synced;

  /// Backend order id once synced.
  final String? serverOrderId;

  /// Human-readable backend order number once synced.
  final String? orderNumber;

  /// Latest fiscal status string (pending/success/failed/null).
  final String? fiscalStatus;

  /// Fiscal QR URL once available.
  final String? fiscalQrUrl;

  /// Cached total so'm for offline listing.
  final int total;
  final DateTime createdAt;
  final DateTime? syncedAt;
  const PendingOrder({
    required this.seq,
    required this.clientUuid,
    required this.payloadJson,
    required this.synced,
    this.serverOrderId,
    this.orderNumber,
    this.fiscalStatus,
    this.fiscalQrUrl,
    required this.total,
    required this.createdAt,
    this.syncedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['seq'] = Variable<int>(seq);
    map['client_uuid'] = Variable<String>(clientUuid);
    map['payload_json'] = Variable<String>(payloadJson);
    map['synced'] = Variable<bool>(synced);
    if (!nullToAbsent || serverOrderId != null) {
      map['server_order_id'] = Variable<String>(serverOrderId);
    }
    if (!nullToAbsent || orderNumber != null) {
      map['order_number'] = Variable<String>(orderNumber);
    }
    if (!nullToAbsent || fiscalStatus != null) {
      map['fiscal_status'] = Variable<String>(fiscalStatus);
    }
    if (!nullToAbsent || fiscalQrUrl != null) {
      map['fiscal_qr_url'] = Variable<String>(fiscalQrUrl);
    }
    map['total'] = Variable<int>(total);
    map['created_at'] = Variable<DateTime>(createdAt);
    if (!nullToAbsent || syncedAt != null) {
      map['synced_at'] = Variable<DateTime>(syncedAt);
    }
    return map;
  }

  PendingOrdersCompanion toCompanion(bool nullToAbsent) {
    return PendingOrdersCompanion(
      seq: Value(seq),
      clientUuid: Value(clientUuid),
      payloadJson: Value(payloadJson),
      synced: Value(synced),
      serverOrderId: serverOrderId == null && nullToAbsent
          ? const Value.absent()
          : Value(serverOrderId),
      orderNumber: orderNumber == null && nullToAbsent
          ? const Value.absent()
          : Value(orderNumber),
      fiscalStatus: fiscalStatus == null && nullToAbsent
          ? const Value.absent()
          : Value(fiscalStatus),
      fiscalQrUrl: fiscalQrUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(fiscalQrUrl),
      total: Value(total),
      createdAt: Value(createdAt),
      syncedAt: syncedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(syncedAt),
    );
  }

  factory PendingOrder.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PendingOrder(
      seq: serializer.fromJson<int>(json['seq']),
      clientUuid: serializer.fromJson<String>(json['clientUuid']),
      payloadJson: serializer.fromJson<String>(json['payloadJson']),
      synced: serializer.fromJson<bool>(json['synced']),
      serverOrderId: serializer.fromJson<String?>(json['serverOrderId']),
      orderNumber: serializer.fromJson<String?>(json['orderNumber']),
      fiscalStatus: serializer.fromJson<String?>(json['fiscalStatus']),
      fiscalQrUrl: serializer.fromJson<String?>(json['fiscalQrUrl']),
      total: serializer.fromJson<int>(json['total']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      syncedAt: serializer.fromJson<DateTime?>(json['syncedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'seq': serializer.toJson<int>(seq),
      'clientUuid': serializer.toJson<String>(clientUuid),
      'payloadJson': serializer.toJson<String>(payloadJson),
      'synced': serializer.toJson<bool>(synced),
      'serverOrderId': serializer.toJson<String?>(serverOrderId),
      'orderNumber': serializer.toJson<String?>(orderNumber),
      'fiscalStatus': serializer.toJson<String?>(fiscalStatus),
      'fiscalQrUrl': serializer.toJson<String?>(fiscalQrUrl),
      'total': serializer.toJson<int>(total),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'syncedAt': serializer.toJson<DateTime?>(syncedAt),
    };
  }

  PendingOrder copyWith({
    int? seq,
    String? clientUuid,
    String? payloadJson,
    bool? synced,
    Value<String?> serverOrderId = const Value.absent(),
    Value<String?> orderNumber = const Value.absent(),
    Value<String?> fiscalStatus = const Value.absent(),
    Value<String?> fiscalQrUrl = const Value.absent(),
    int? total,
    DateTime? createdAt,
    Value<DateTime?> syncedAt = const Value.absent(),
  }) => PendingOrder(
    seq: seq ?? this.seq,
    clientUuid: clientUuid ?? this.clientUuid,
    payloadJson: payloadJson ?? this.payloadJson,
    synced: synced ?? this.synced,
    serverOrderId: serverOrderId.present
        ? serverOrderId.value
        : this.serverOrderId,
    orderNumber: orderNumber.present ? orderNumber.value : this.orderNumber,
    fiscalStatus: fiscalStatus.present ? fiscalStatus.value : this.fiscalStatus,
    fiscalQrUrl: fiscalQrUrl.present ? fiscalQrUrl.value : this.fiscalQrUrl,
    total: total ?? this.total,
    createdAt: createdAt ?? this.createdAt,
    syncedAt: syncedAt.present ? syncedAt.value : this.syncedAt,
  );
  PendingOrder copyWithCompanion(PendingOrdersCompanion data) {
    return PendingOrder(
      seq: data.seq.present ? data.seq.value : this.seq,
      clientUuid: data.clientUuid.present
          ? data.clientUuid.value
          : this.clientUuid,
      payloadJson: data.payloadJson.present
          ? data.payloadJson.value
          : this.payloadJson,
      synced: data.synced.present ? data.synced.value : this.synced,
      serverOrderId: data.serverOrderId.present
          ? data.serverOrderId.value
          : this.serverOrderId,
      orderNumber: data.orderNumber.present
          ? data.orderNumber.value
          : this.orderNumber,
      fiscalStatus: data.fiscalStatus.present
          ? data.fiscalStatus.value
          : this.fiscalStatus,
      fiscalQrUrl: data.fiscalQrUrl.present
          ? data.fiscalQrUrl.value
          : this.fiscalQrUrl,
      total: data.total.present ? data.total.value : this.total,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      syncedAt: data.syncedAt.present ? data.syncedAt.value : this.syncedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PendingOrder(')
          ..write('seq: $seq, ')
          ..write('clientUuid: $clientUuid, ')
          ..write('payloadJson: $payloadJson, ')
          ..write('synced: $synced, ')
          ..write('serverOrderId: $serverOrderId, ')
          ..write('orderNumber: $orderNumber, ')
          ..write('fiscalStatus: $fiscalStatus, ')
          ..write('fiscalQrUrl: $fiscalQrUrl, ')
          ..write('total: $total, ')
          ..write('createdAt: $createdAt, ')
          ..write('syncedAt: $syncedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    seq,
    clientUuid,
    payloadJson,
    synced,
    serverOrderId,
    orderNumber,
    fiscalStatus,
    fiscalQrUrl,
    total,
    createdAt,
    syncedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PendingOrder &&
          other.seq == this.seq &&
          other.clientUuid == this.clientUuid &&
          other.payloadJson == this.payloadJson &&
          other.synced == this.synced &&
          other.serverOrderId == this.serverOrderId &&
          other.orderNumber == this.orderNumber &&
          other.fiscalStatus == this.fiscalStatus &&
          other.fiscalQrUrl == this.fiscalQrUrl &&
          other.total == this.total &&
          other.createdAt == this.createdAt &&
          other.syncedAt == this.syncedAt);
}

class PendingOrdersCompanion extends UpdateCompanion<PendingOrder> {
  final Value<int> seq;
  final Value<String> clientUuid;
  final Value<String> payloadJson;
  final Value<bool> synced;
  final Value<String?> serverOrderId;
  final Value<String?> orderNumber;
  final Value<String?> fiscalStatus;
  final Value<String?> fiscalQrUrl;
  final Value<int> total;
  final Value<DateTime> createdAt;
  final Value<DateTime?> syncedAt;
  const PendingOrdersCompanion({
    this.seq = const Value.absent(),
    this.clientUuid = const Value.absent(),
    this.payloadJson = const Value.absent(),
    this.synced = const Value.absent(),
    this.serverOrderId = const Value.absent(),
    this.orderNumber = const Value.absent(),
    this.fiscalStatus = const Value.absent(),
    this.fiscalQrUrl = const Value.absent(),
    this.total = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.syncedAt = const Value.absent(),
  });
  PendingOrdersCompanion.insert({
    this.seq = const Value.absent(),
    required String clientUuid,
    required String payloadJson,
    this.synced = const Value.absent(),
    this.serverOrderId = const Value.absent(),
    this.orderNumber = const Value.absent(),
    this.fiscalStatus = const Value.absent(),
    this.fiscalQrUrl = const Value.absent(),
    this.total = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.syncedAt = const Value.absent(),
  }) : clientUuid = Value(clientUuid),
       payloadJson = Value(payloadJson);
  static Insertable<PendingOrder> custom({
    Expression<int>? seq,
    Expression<String>? clientUuid,
    Expression<String>? payloadJson,
    Expression<bool>? synced,
    Expression<String>? serverOrderId,
    Expression<String>? orderNumber,
    Expression<String>? fiscalStatus,
    Expression<String>? fiscalQrUrl,
    Expression<int>? total,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? syncedAt,
  }) {
    return RawValuesInsertable({
      if (seq != null) 'seq': seq,
      if (clientUuid != null) 'client_uuid': clientUuid,
      if (payloadJson != null) 'payload_json': payloadJson,
      if (synced != null) 'synced': synced,
      if (serverOrderId != null) 'server_order_id': serverOrderId,
      if (orderNumber != null) 'order_number': orderNumber,
      if (fiscalStatus != null) 'fiscal_status': fiscalStatus,
      if (fiscalQrUrl != null) 'fiscal_qr_url': fiscalQrUrl,
      if (total != null) 'total': total,
      if (createdAt != null) 'created_at': createdAt,
      if (syncedAt != null) 'synced_at': syncedAt,
    });
  }

  PendingOrdersCompanion copyWith({
    Value<int>? seq,
    Value<String>? clientUuid,
    Value<String>? payloadJson,
    Value<bool>? synced,
    Value<String?>? serverOrderId,
    Value<String?>? orderNumber,
    Value<String?>? fiscalStatus,
    Value<String?>? fiscalQrUrl,
    Value<int>? total,
    Value<DateTime>? createdAt,
    Value<DateTime?>? syncedAt,
  }) {
    return PendingOrdersCompanion(
      seq: seq ?? this.seq,
      clientUuid: clientUuid ?? this.clientUuid,
      payloadJson: payloadJson ?? this.payloadJson,
      synced: synced ?? this.synced,
      serverOrderId: serverOrderId ?? this.serverOrderId,
      orderNumber: orderNumber ?? this.orderNumber,
      fiscalStatus: fiscalStatus ?? this.fiscalStatus,
      fiscalQrUrl: fiscalQrUrl ?? this.fiscalQrUrl,
      total: total ?? this.total,
      createdAt: createdAt ?? this.createdAt,
      syncedAt: syncedAt ?? this.syncedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (seq.present) {
      map['seq'] = Variable<int>(seq.value);
    }
    if (clientUuid.present) {
      map['client_uuid'] = Variable<String>(clientUuid.value);
    }
    if (payloadJson.present) {
      map['payload_json'] = Variable<String>(payloadJson.value);
    }
    if (synced.present) {
      map['synced'] = Variable<bool>(synced.value);
    }
    if (serverOrderId.present) {
      map['server_order_id'] = Variable<String>(serverOrderId.value);
    }
    if (orderNumber.present) {
      map['order_number'] = Variable<String>(orderNumber.value);
    }
    if (fiscalStatus.present) {
      map['fiscal_status'] = Variable<String>(fiscalStatus.value);
    }
    if (fiscalQrUrl.present) {
      map['fiscal_qr_url'] = Variable<String>(fiscalQrUrl.value);
    }
    if (total.present) {
      map['total'] = Variable<int>(total.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (syncedAt.present) {
      map['synced_at'] = Variable<DateTime>(syncedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PendingOrdersCompanion(')
          ..write('seq: $seq, ')
          ..write('clientUuid: $clientUuid, ')
          ..write('payloadJson: $payloadJson, ')
          ..write('synced: $synced, ')
          ..write('serverOrderId: $serverOrderId, ')
          ..write('orderNumber: $orderNumber, ')
          ..write('fiscalStatus: $fiscalStatus, ')
          ..write('fiscalQrUrl: $fiscalQrUrl, ')
          ..write('total: $total, ')
          ..write('createdAt: $createdAt, ')
          ..write('syncedAt: $syncedAt')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $CachedCategoriesTable cachedCategories = $CachedCategoriesTable(
    this,
  );
  late final $CachedProductsTable cachedProducts = $CachedProductsTable(this);
  late final $PendingOrdersTable pendingOrders = $PendingOrdersTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    cachedCategories,
    cachedProducts,
    pendingOrders,
  ];
}

typedef $$CachedCategoriesTableCreateCompanionBuilder =
    CachedCategoriesCompanion Function({
      required String id,
      required String name,
      Value<int> sortOrder,
      Value<String?> imageUrl,
      Value<int> rowid,
    });
typedef $$CachedCategoriesTableUpdateCompanionBuilder =
    CachedCategoriesCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<int> sortOrder,
      Value<String?> imageUrl,
      Value<int> rowid,
    });

class $$CachedCategoriesTableFilterComposer
    extends Composer<_$AppDatabase, $CachedCategoriesTable> {
  $$CachedCategoriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get imageUrl => $composableBuilder(
    column: $table.imageUrl,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CachedCategoriesTableOrderingComposer
    extends Composer<_$AppDatabase, $CachedCategoriesTable> {
  $$CachedCategoriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get imageUrl => $composableBuilder(
    column: $table.imageUrl,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CachedCategoriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $CachedCategoriesTable> {
  $$CachedCategoriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  GeneratedColumn<String> get imageUrl =>
      $composableBuilder(column: $table.imageUrl, builder: (column) => column);
}

class $$CachedCategoriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CachedCategoriesTable,
          CachedCategory,
          $$CachedCategoriesTableFilterComposer,
          $$CachedCategoriesTableOrderingComposer,
          $$CachedCategoriesTableAnnotationComposer,
          $$CachedCategoriesTableCreateCompanionBuilder,
          $$CachedCategoriesTableUpdateCompanionBuilder,
          (
            CachedCategory,
            BaseReferences<
              _$AppDatabase,
              $CachedCategoriesTable,
              CachedCategory
            >,
          ),
          CachedCategory,
          PrefetchHooks Function()
        > {
  $$CachedCategoriesTableTableManager(
    _$AppDatabase db,
    $CachedCategoriesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CachedCategoriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CachedCategoriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CachedCategoriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<String?> imageUrl = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CachedCategoriesCompanion(
                id: id,
                name: name,
                sortOrder: sortOrder,
                imageUrl: imageUrl,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                Value<int> sortOrder = const Value.absent(),
                Value<String?> imageUrl = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CachedCategoriesCompanion.insert(
                id: id,
                name: name,
                sortOrder: sortOrder,
                imageUrl: imageUrl,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CachedCategoriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CachedCategoriesTable,
      CachedCategory,
      $$CachedCategoriesTableFilterComposer,
      $$CachedCategoriesTableOrderingComposer,
      $$CachedCategoriesTableAnnotationComposer,
      $$CachedCategoriesTableCreateCompanionBuilder,
      $$CachedCategoriesTableUpdateCompanionBuilder,
      (
        CachedCategory,
        BaseReferences<_$AppDatabase, $CachedCategoriesTable, CachedCategory>,
      ),
      CachedCategory,
      PrefetchHooks Function()
    >;
typedef $$CachedProductsTableCreateCompanionBuilder =
    CachedProductsCompanion Function({
      required String id,
      Value<String?> categoryId,
      required String name,
      Value<String?> sku,
      Value<double> price,
      Value<String?> mxikCode,
      Value<String?> packageCode,
      Value<double> vatPercent,
      Value<String> unit,
      Value<String?> imageUrl,
      Value<bool> isActive,
      Value<bool> markingRequired,
      Value<bool> trackStock,
      Value<double> stockQty,
      Value<double> lowStockThreshold,
      Value<int> rowid,
    });
typedef $$CachedProductsTableUpdateCompanionBuilder =
    CachedProductsCompanion Function({
      Value<String> id,
      Value<String?> categoryId,
      Value<String> name,
      Value<String?> sku,
      Value<double> price,
      Value<String?> mxikCode,
      Value<String?> packageCode,
      Value<double> vatPercent,
      Value<String> unit,
      Value<String?> imageUrl,
      Value<bool> isActive,
      Value<bool> markingRequired,
      Value<bool> trackStock,
      Value<double> stockQty,
      Value<double> lowStockThreshold,
      Value<int> rowid,
    });

class $$CachedProductsTableFilterComposer
    extends Composer<_$AppDatabase, $CachedProductsTable> {
  $$CachedProductsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get categoryId => $composableBuilder(
    column: $table.categoryId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sku => $composableBuilder(
    column: $table.sku,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get price => $composableBuilder(
    column: $table.price,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get mxikCode => $composableBuilder(
    column: $table.mxikCode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get packageCode => $composableBuilder(
    column: $table.packageCode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get vatPercent => $composableBuilder(
    column: $table.vatPercent,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get unit => $composableBuilder(
    column: $table.unit,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get imageUrl => $composableBuilder(
    column: $table.imageUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isActive => $composableBuilder(
    column: $table.isActive,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get markingRequired => $composableBuilder(
    column: $table.markingRequired,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get trackStock => $composableBuilder(
    column: $table.trackStock,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get stockQty => $composableBuilder(
    column: $table.stockQty,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get lowStockThreshold => $composableBuilder(
    column: $table.lowStockThreshold,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CachedProductsTableOrderingComposer
    extends Composer<_$AppDatabase, $CachedProductsTable> {
  $$CachedProductsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get categoryId => $composableBuilder(
    column: $table.categoryId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sku => $composableBuilder(
    column: $table.sku,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get price => $composableBuilder(
    column: $table.price,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get mxikCode => $composableBuilder(
    column: $table.mxikCode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get packageCode => $composableBuilder(
    column: $table.packageCode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get vatPercent => $composableBuilder(
    column: $table.vatPercent,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get unit => $composableBuilder(
    column: $table.unit,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get imageUrl => $composableBuilder(
    column: $table.imageUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isActive => $composableBuilder(
    column: $table.isActive,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get markingRequired => $composableBuilder(
    column: $table.markingRequired,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get trackStock => $composableBuilder(
    column: $table.trackStock,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get stockQty => $composableBuilder(
    column: $table.stockQty,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get lowStockThreshold => $composableBuilder(
    column: $table.lowStockThreshold,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CachedProductsTableAnnotationComposer
    extends Composer<_$AppDatabase, $CachedProductsTable> {
  $$CachedProductsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get categoryId => $composableBuilder(
    column: $table.categoryId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get sku =>
      $composableBuilder(column: $table.sku, builder: (column) => column);

  GeneratedColumn<double> get price =>
      $composableBuilder(column: $table.price, builder: (column) => column);

  GeneratedColumn<String> get mxikCode =>
      $composableBuilder(column: $table.mxikCode, builder: (column) => column);

  GeneratedColumn<String> get packageCode => $composableBuilder(
    column: $table.packageCode,
    builder: (column) => column,
  );

  GeneratedColumn<double> get vatPercent => $composableBuilder(
    column: $table.vatPercent,
    builder: (column) => column,
  );

  GeneratedColumn<String> get unit =>
      $composableBuilder(column: $table.unit, builder: (column) => column);

  GeneratedColumn<String> get imageUrl =>
      $composableBuilder(column: $table.imageUrl, builder: (column) => column);

  GeneratedColumn<bool> get isActive =>
      $composableBuilder(column: $table.isActive, builder: (column) => column);

  GeneratedColumn<bool> get markingRequired => $composableBuilder(
    column: $table.markingRequired,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get trackStock => $composableBuilder(
    column: $table.trackStock,
    builder: (column) => column,
  );

  GeneratedColumn<double> get stockQty =>
      $composableBuilder(column: $table.stockQty, builder: (column) => column);

  GeneratedColumn<double> get lowStockThreshold => $composableBuilder(
    column: $table.lowStockThreshold,
    builder: (column) => column,
  );
}

class $$CachedProductsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CachedProductsTable,
          CachedProduct,
          $$CachedProductsTableFilterComposer,
          $$CachedProductsTableOrderingComposer,
          $$CachedProductsTableAnnotationComposer,
          $$CachedProductsTableCreateCompanionBuilder,
          $$CachedProductsTableUpdateCompanionBuilder,
          (
            CachedProduct,
            BaseReferences<_$AppDatabase, $CachedProductsTable, CachedProduct>,
          ),
          CachedProduct,
          PrefetchHooks Function()
        > {
  $$CachedProductsTableTableManager(
    _$AppDatabase db,
    $CachedProductsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CachedProductsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CachedProductsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CachedProductsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String?> categoryId = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String?> sku = const Value.absent(),
                Value<double> price = const Value.absent(),
                Value<String?> mxikCode = const Value.absent(),
                Value<String?> packageCode = const Value.absent(),
                Value<double> vatPercent = const Value.absent(),
                Value<String> unit = const Value.absent(),
                Value<String?> imageUrl = const Value.absent(),
                Value<bool> isActive = const Value.absent(),
                Value<bool> markingRequired = const Value.absent(),
                Value<bool> trackStock = const Value.absent(),
                Value<double> stockQty = const Value.absent(),
                Value<double> lowStockThreshold = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CachedProductsCompanion(
                id: id,
                categoryId: categoryId,
                name: name,
                sku: sku,
                price: price,
                mxikCode: mxikCode,
                packageCode: packageCode,
                vatPercent: vatPercent,
                unit: unit,
                imageUrl: imageUrl,
                isActive: isActive,
                markingRequired: markingRequired,
                trackStock: trackStock,
                stockQty: stockQty,
                lowStockThreshold: lowStockThreshold,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<String?> categoryId = const Value.absent(),
                required String name,
                Value<String?> sku = const Value.absent(),
                Value<double> price = const Value.absent(),
                Value<String?> mxikCode = const Value.absent(),
                Value<String?> packageCode = const Value.absent(),
                Value<double> vatPercent = const Value.absent(),
                Value<String> unit = const Value.absent(),
                Value<String?> imageUrl = const Value.absent(),
                Value<bool> isActive = const Value.absent(),
                Value<bool> markingRequired = const Value.absent(),
                Value<bool> trackStock = const Value.absent(),
                Value<double> stockQty = const Value.absent(),
                Value<double> lowStockThreshold = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CachedProductsCompanion.insert(
                id: id,
                categoryId: categoryId,
                name: name,
                sku: sku,
                price: price,
                mxikCode: mxikCode,
                packageCode: packageCode,
                vatPercent: vatPercent,
                unit: unit,
                imageUrl: imageUrl,
                isActive: isActive,
                markingRequired: markingRequired,
                trackStock: trackStock,
                stockQty: stockQty,
                lowStockThreshold: lowStockThreshold,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CachedProductsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CachedProductsTable,
      CachedProduct,
      $$CachedProductsTableFilterComposer,
      $$CachedProductsTableOrderingComposer,
      $$CachedProductsTableAnnotationComposer,
      $$CachedProductsTableCreateCompanionBuilder,
      $$CachedProductsTableUpdateCompanionBuilder,
      (
        CachedProduct,
        BaseReferences<_$AppDatabase, $CachedProductsTable, CachedProduct>,
      ),
      CachedProduct,
      PrefetchHooks Function()
    >;
typedef $$PendingOrdersTableCreateCompanionBuilder =
    PendingOrdersCompanion Function({
      Value<int> seq,
      required String clientUuid,
      required String payloadJson,
      Value<bool> synced,
      Value<String?> serverOrderId,
      Value<String?> orderNumber,
      Value<String?> fiscalStatus,
      Value<String?> fiscalQrUrl,
      Value<int> total,
      Value<DateTime> createdAt,
      Value<DateTime?> syncedAt,
    });
typedef $$PendingOrdersTableUpdateCompanionBuilder =
    PendingOrdersCompanion Function({
      Value<int> seq,
      Value<String> clientUuid,
      Value<String> payloadJson,
      Value<bool> synced,
      Value<String?> serverOrderId,
      Value<String?> orderNumber,
      Value<String?> fiscalStatus,
      Value<String?> fiscalQrUrl,
      Value<int> total,
      Value<DateTime> createdAt,
      Value<DateTime?> syncedAt,
    });

class $$PendingOrdersTableFilterComposer
    extends Composer<_$AppDatabase, $PendingOrdersTable> {
  $$PendingOrdersTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get seq => $composableBuilder(
    column: $table.seq,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get clientUuid => $composableBuilder(
    column: $table.clientUuid,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get synced => $composableBuilder(
    column: $table.synced,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get serverOrderId => $composableBuilder(
    column: $table.serverOrderId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get orderNumber => $composableBuilder(
    column: $table.orderNumber,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get fiscalStatus => $composableBuilder(
    column: $table.fiscalStatus,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get fiscalQrUrl => $composableBuilder(
    column: $table.fiscalQrUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get total => $composableBuilder(
    column: $table.total,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get syncedAt => $composableBuilder(
    column: $table.syncedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$PendingOrdersTableOrderingComposer
    extends Composer<_$AppDatabase, $PendingOrdersTable> {
  $$PendingOrdersTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get seq => $composableBuilder(
    column: $table.seq,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get clientUuid => $composableBuilder(
    column: $table.clientUuid,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get synced => $composableBuilder(
    column: $table.synced,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get serverOrderId => $composableBuilder(
    column: $table.serverOrderId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get orderNumber => $composableBuilder(
    column: $table.orderNumber,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get fiscalStatus => $composableBuilder(
    column: $table.fiscalStatus,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get fiscalQrUrl => $composableBuilder(
    column: $table.fiscalQrUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get total => $composableBuilder(
    column: $table.total,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get syncedAt => $composableBuilder(
    column: $table.syncedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PendingOrdersTableAnnotationComposer
    extends Composer<_$AppDatabase, $PendingOrdersTable> {
  $$PendingOrdersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get seq =>
      $composableBuilder(column: $table.seq, builder: (column) => column);

  GeneratedColumn<String> get clientUuid => $composableBuilder(
    column: $table.clientUuid,
    builder: (column) => column,
  );

  GeneratedColumn<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get synced =>
      $composableBuilder(column: $table.synced, builder: (column) => column);

  GeneratedColumn<String> get serverOrderId => $composableBuilder(
    column: $table.serverOrderId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get orderNumber => $composableBuilder(
    column: $table.orderNumber,
    builder: (column) => column,
  );

  GeneratedColumn<String> get fiscalStatus => $composableBuilder(
    column: $table.fiscalStatus,
    builder: (column) => column,
  );

  GeneratedColumn<String> get fiscalQrUrl => $composableBuilder(
    column: $table.fiscalQrUrl,
    builder: (column) => column,
  );

  GeneratedColumn<int> get total =>
      $composableBuilder(column: $table.total, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get syncedAt =>
      $composableBuilder(column: $table.syncedAt, builder: (column) => column);
}

class $$PendingOrdersTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PendingOrdersTable,
          PendingOrder,
          $$PendingOrdersTableFilterComposer,
          $$PendingOrdersTableOrderingComposer,
          $$PendingOrdersTableAnnotationComposer,
          $$PendingOrdersTableCreateCompanionBuilder,
          $$PendingOrdersTableUpdateCompanionBuilder,
          (
            PendingOrder,
            BaseReferences<_$AppDatabase, $PendingOrdersTable, PendingOrder>,
          ),
          PendingOrder,
          PrefetchHooks Function()
        > {
  $$PendingOrdersTableTableManager(_$AppDatabase db, $PendingOrdersTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PendingOrdersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PendingOrdersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PendingOrdersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> seq = const Value.absent(),
                Value<String> clientUuid = const Value.absent(),
                Value<String> payloadJson = const Value.absent(),
                Value<bool> synced = const Value.absent(),
                Value<String?> serverOrderId = const Value.absent(),
                Value<String?> orderNumber = const Value.absent(),
                Value<String?> fiscalStatus = const Value.absent(),
                Value<String?> fiscalQrUrl = const Value.absent(),
                Value<int> total = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime?> syncedAt = const Value.absent(),
              }) => PendingOrdersCompanion(
                seq: seq,
                clientUuid: clientUuid,
                payloadJson: payloadJson,
                synced: synced,
                serverOrderId: serverOrderId,
                orderNumber: orderNumber,
                fiscalStatus: fiscalStatus,
                fiscalQrUrl: fiscalQrUrl,
                total: total,
                createdAt: createdAt,
                syncedAt: syncedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> seq = const Value.absent(),
                required String clientUuid,
                required String payloadJson,
                Value<bool> synced = const Value.absent(),
                Value<String?> serverOrderId = const Value.absent(),
                Value<String?> orderNumber = const Value.absent(),
                Value<String?> fiscalStatus = const Value.absent(),
                Value<String?> fiscalQrUrl = const Value.absent(),
                Value<int> total = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime?> syncedAt = const Value.absent(),
              }) => PendingOrdersCompanion.insert(
                seq: seq,
                clientUuid: clientUuid,
                payloadJson: payloadJson,
                synced: synced,
                serverOrderId: serverOrderId,
                orderNumber: orderNumber,
                fiscalStatus: fiscalStatus,
                fiscalQrUrl: fiscalQrUrl,
                total: total,
                createdAt: createdAt,
                syncedAt: syncedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$PendingOrdersTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PendingOrdersTable,
      PendingOrder,
      $$PendingOrdersTableFilterComposer,
      $$PendingOrdersTableOrderingComposer,
      $$PendingOrdersTableAnnotationComposer,
      $$PendingOrdersTableCreateCompanionBuilder,
      $$PendingOrdersTableUpdateCompanionBuilder,
      (
        PendingOrder,
        BaseReferences<_$AppDatabase, $PendingOrdersTable, PendingOrder>,
      ),
      PendingOrder,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$CachedCategoriesTableTableManager get cachedCategories =>
      $$CachedCategoriesTableTableManager(_db, _db.cachedCategories);
  $$CachedProductsTableTableManager get cachedProducts =>
      $$CachedProductsTableTableManager(_db, _db.cachedProducts);
  $$PendingOrdersTableTableManager get pendingOrders =>
      $$PendingOrdersTableTableManager(_db, _db.pendingOrders);
}
