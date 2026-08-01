#pragma warning disable 618
#pragma warning disable 612
#pragma warning disable 414
#pragma warning disable 168

namespace Utf8Json.Resolvers
{
    using System;
    using Utf8Json;

    public class GeneratedResolver : global::Utf8Json.IJsonFormatterResolver
    {
        public static readonly global::Utf8Json.IJsonFormatterResolver Instance = new GeneratedResolver();

        GeneratedResolver()
        {

        }

        public global::Utf8Json.IJsonFormatter<T> GetFormatter<T>()
        {
            return FormatterCache<T>.formatter;
        }

        static class FormatterCache<T>
        {
            public static readonly global::Utf8Json.IJsonFormatter<T> formatter;

            static FormatterCache()
            {
                var f = GeneratedResolverGetFormatterHelper.GetFormatter(typeof(T));
                if (f != null)
                {
                    formatter = (global::Utf8Json.IJsonFormatter<T>)f;
                }
            }
        }
    }

    internal static class GeneratedResolverGetFormatterHelper
    {
        static readonly global::System.Collections.Generic.Dictionary<Type, int> lookup;

        static GeneratedResolverGetFormatterHelper()
        {
            lookup = new global::System.Collections.Generic.Dictionary<Type, int>(4)
            {
                {typeof(global::Article[]), 0 },
                {typeof(global::CoreCompTableData), 1 },
                {typeof(global::Article), 2 },
                {typeof(global::Range), 3 },
            };
        }

        internal static object GetFormatter(Type t)
        {
            int key;
            if (!lookup.TryGetValue(t, out key)) return null;

            switch (key)
            {
                case 0: return new global::Utf8Json.Formatters.ArrayFormatter<global::Article>();
                case 1: return new Utf8Json.Formatters.CoreCompTableDataFormatter();
                case 2: return new Utf8Json.Formatters.ArticleFormatter();
                case 3: return new Utf8Json.Formatters.RangeFormatter();
                default: return null;
            }
        }
    }
}

#pragma warning disable 168
#pragma warning restore 414
#pragma warning restore 618
#pragma warning restore 612

#pragma warning disable 618
#pragma warning disable 612
#pragma warning disable 414
#pragma warning disable 219
#pragma warning disable 168

namespace Utf8Json.Formatters
{
    using System;
    using Utf8Json;


    public sealed class CoreCompTableDataFormatter : global::Utf8Json.IJsonFormatter<global::CoreCompTableData>
    {
        readonly global::Utf8Json.Internal.AutomataDictionary ____keyMapping;
        readonly byte[][] ____stringByteKeys;

        public CoreCompTableDataFormatter()
        {
            this.____keyMapping = new global::Utf8Json.Internal.AutomataDictionary()
            {
                { JsonWriter.GetEncodedPropertyNameWithoutQuotation("id"), 0},
                { JsonWriter.GetEncodedPropertyNameWithoutQuotation("idText"), 1},
                { JsonWriter.GetEncodedPropertyNameWithoutQuotation("type"), 2},
                { JsonWriter.GetEncodedPropertyNameWithoutQuotation("name"), 3},
                { JsonWriter.GetEncodedPropertyNameWithoutQuotation("describe"), 4},
                { JsonWriter.GetEncodedPropertyNameWithoutQuotation("manufacturer"), 5},
                { JsonWriter.GetEncodedPropertyNameWithoutQuotation("model"), 6},
                { JsonWriter.GetEncodedPropertyNameWithoutQuotation("color"), 7},
                { JsonWriter.GetEncodedPropertyNameWithoutQuotation("quality"), 8},
                { JsonWriter.GetEncodedPropertyNameWithoutQuotation("price"), 9},
                { JsonWriter.GetEncodedPropertyNameWithoutQuotation("tier"), 10},
                { JsonWriter.GetEncodedPropertyNameWithoutQuotation("releaseDate"), 11},
                { JsonWriter.GetEncodedPropertyNameWithoutQuotation("imagePath"), 12},
                { JsonWriter.GetEncodedPropertyNameWithoutQuotation("size"), 13},
            };

            this.____stringByteKeys = new byte[][]
            {
                JsonWriter.GetEncodedPropertyNameWithBeginObject("id"),
                JsonWriter.GetEncodedPropertyNameWithPrefixValueSeparator("idText"),
                JsonWriter.GetEncodedPropertyNameWithPrefixValueSeparator("type"),
                JsonWriter.GetEncodedPropertyNameWithPrefixValueSeparator("name"),
                JsonWriter.GetEncodedPropertyNameWithPrefixValueSeparator("describe"),
                JsonWriter.GetEncodedPropertyNameWithPrefixValueSeparator("manufacturer"),
                JsonWriter.GetEncodedPropertyNameWithPrefixValueSeparator("model"),
                JsonWriter.GetEncodedPropertyNameWithPrefixValueSeparator("color"),
                JsonWriter.GetEncodedPropertyNameWithPrefixValueSeparator("quality"),
                JsonWriter.GetEncodedPropertyNameWithPrefixValueSeparator("price"),
                JsonWriter.GetEncodedPropertyNameWithPrefixValueSeparator("tier"),
                JsonWriter.GetEncodedPropertyNameWithPrefixValueSeparator("releaseDate"),
                JsonWriter.GetEncodedPropertyNameWithPrefixValueSeparator("imagePath"),
                JsonWriter.GetEncodedPropertyNameWithPrefixValueSeparator("size"),
                
            };
        }

        public void Serialize(ref JsonWriter writer, global::CoreCompTableData value, global::Utf8Json.IJsonFormatterResolver formatterResolver)
        {
            if (value == null)
            {
                writer.WriteNull();
                return;
            }
            

            writer.WriteRaw(this.____stringByteKeys[0]);
            writer.WriteInt32(value.id);
            writer.WriteRaw(this.____stringByteKeys[1]);
            writer.WriteString(value.idText);
            writer.WriteRaw(this.____stringByteKeys[2]);
            writer.WriteString(value.type);
            writer.WriteRaw(this.____stringByteKeys[3]);
            writer.WriteString(value.name);
            writer.WriteRaw(this.____stringByteKeys[4]);
            writer.WriteString(value.describe);
            writer.WriteRaw(this.____stringByteKeys[5]);
            writer.WriteString(value.manufacturer);
            writer.WriteRaw(this.____stringByteKeys[6]);
            writer.WriteString(value.model);
            writer.WriteRaw(this.____stringByteKeys[7]);
            writer.WriteString(value.color);
            writer.WriteRaw(this.____stringByteKeys[8]);
            writer.WriteString(value.quality);
            writer.WriteRaw(this.____stringByteKeys[9]);
            writer.WriteInt32(value.price);
            writer.WriteRaw(this.____stringByteKeys[10]);
            writer.WriteInt32(value.tier);
            writer.WriteRaw(this.____stringByteKeys[11]);
            writer.WriteString(value.releaseDate);
            writer.WriteRaw(this.____stringByteKeys[12]);
            writer.WriteString(value.imagePath);
            writer.WriteRaw(this.____stringByteKeys[13]);
            writer.WriteString(value.size);
            
            writer.WriteEndObject();
        }

        public global::CoreCompTableData Deserialize(ref JsonReader reader, global::Utf8Json.IJsonFormatterResolver formatterResolver)
        {
            if (reader.ReadIsNull())
            {
                return null;
            }
            

            var __id__ = default(int);
            var __id__b__ = false;
            var __idText__ = default(string);
            var __idText__b__ = false;
            var __type__ = default(string);
            var __type__b__ = false;
            var __name__ = default(string);
            var __name__b__ = false;
            var __describe__ = default(string);
            var __describe__b__ = false;
            var __manufacturer__ = default(string);
            var __manufacturer__b__ = false;
            var __model__ = default(string);
            var __model__b__ = false;
            var __color__ = default(string);
            var __color__b__ = false;
            var __quality__ = default(string);
            var __quality__b__ = false;
            var __price__ = default(int);
            var __price__b__ = false;
            var __tier__ = default(int);
            var __tier__b__ = false;
            var __releaseDate__ = default(string);
            var __releaseDate__b__ = false;
            var __imagePath__ = default(string);
            var __imagePath__b__ = false;
            var __size__ = default(string);
            var __size__b__ = false;

            var ____count = 0;
            reader.ReadIsBeginObjectWithVerify();
            while (!reader.ReadIsEndObjectWithSkipValueSeparator(ref ____count))
            {
                var stringKey = reader.ReadPropertyNameSegmentRaw();
                int key;
                if (!____keyMapping.TryGetValueSafe(stringKey, out key))
                {
                    reader.ReadNextBlock();
                    goto NEXT_LOOP;
                }

                switch (key)
                {
                    case 0:
                        __id__ = reader.ReadInt32();
                        __id__b__ = true;
                        break;
                    case 1:
                        __idText__ = reader.ReadString();
                        __idText__b__ = true;
                        break;
                    case 2:
                        __type__ = reader.ReadString();
                        __type__b__ = true;
                        break;
                    case 3:
                        __name__ = reader.ReadString();
                        __name__b__ = true;
                        break;
                    case 4:
                        __describe__ = reader.ReadString();
                        __describe__b__ = true;
                        break;
                    case 5:
                        __manufacturer__ = reader.ReadString();
                        __manufacturer__b__ = true;
                        break;
                    case 6:
                        __model__ = reader.ReadString();
                        __model__b__ = true;
                        break;
                    case 7:
                        __color__ = reader.ReadString();
                        __color__b__ = true;
                        break;
                    case 8:
                        __quality__ = reader.ReadString();
                        __quality__b__ = true;
                        break;
                    case 9:
                        __price__ = reader.ReadInt32();
                        __price__b__ = true;
                        break;
                    case 10:
                        __tier__ = reader.ReadInt32();
                        __tier__b__ = true;
                        break;
                    case 11:
                        __releaseDate__ = reader.ReadString();
                        __releaseDate__b__ = true;
                        break;
                    case 12:
                        __imagePath__ = reader.ReadString();
                        __imagePath__b__ = true;
                        break;
                    case 13:
                        __size__ = reader.ReadString();
                        __size__b__ = true;
                        break;
                    default:
                        reader.ReadNextBlock();
                        break;
                }

                NEXT_LOOP:
                continue;
            }

            var ____result = new global::CoreCompTableData();
            if(__id__b__) ____result.id = __id__;
            if(__idText__b__) ____result.idText = __idText__;
            if(__type__b__) ____result.type = __type__;
            if(__name__b__) ____result.name = __name__;
            if(__describe__b__) ____result.describe = __describe__;
            if(__manufacturer__b__) ____result.manufacturer = __manufacturer__;
            if(__model__b__) ____result.model = __model__;
            if(__color__b__) ____result.color = __color__;
            if(__quality__b__) ____result.quality = __quality__;
            if(__price__b__) ____result.price = __price__;
            if(__tier__b__) ____result.tier = __tier__;
            if(__releaseDate__b__) ____result.releaseDate = __releaseDate__;
            if(__imagePath__b__) ____result.imagePath = __imagePath__;
            if(__size__b__) ____result.size = __size__;

            return ____result;
        }
    }


    public sealed class ArticleFormatter : global::Utf8Json.IJsonFormatter<global::Article>
    {
        readonly global::Utf8Json.Internal.AutomataDictionary ____keyMapping;
        readonly byte[][] ____stringByteKeys;

        public ArticleFormatter()
        {
            this.____keyMapping = new global::Utf8Json.Internal.AutomataDictionary()
            {
                { JsonWriter.GetEncodedPropertyNameWithoutQuotation("id"), 0},
                { JsonWriter.GetEncodedPropertyNameWithoutQuotation("count"), 1},
                { JsonWriter.GetEncodedPropertyNameWithoutQuotation("subArticles"), 2},
            };

            this.____stringByteKeys = new byte[][]
            {
                JsonWriter.GetEncodedPropertyNameWithBeginObject("id"),
                JsonWriter.GetEncodedPropertyNameWithPrefixValueSeparator("count"),
                JsonWriter.GetEncodedPropertyNameWithPrefixValueSeparator("subArticles"),
                
            };
        }

        public void Serialize(ref JsonWriter writer, global::Article value, global::Utf8Json.IJsonFormatterResolver formatterResolver)
        {
            if (value == null)
            {
                writer.WriteNull();
                return;
            }
            

            writer.WriteRaw(this.____stringByteKeys[0]);
            writer.WriteInt32(value.id);
            writer.WriteRaw(this.____stringByteKeys[1]);
            writer.WriteInt32(value.count);
            writer.WriteRaw(this.____stringByteKeys[2]);
            formatterResolver.GetFormatterWithVerify<global::Article[]>().Serialize(ref writer, value.subArticles, formatterResolver);
            
            writer.WriteEndObject();
        }

        public global::Article Deserialize(ref JsonReader reader, global::Utf8Json.IJsonFormatterResolver formatterResolver)
        {
            if (reader.ReadIsNull())
            {
                return null;
            }
            

            var __id__ = default(int);
            var __id__b__ = false;
            var __count__ = default(int);
            var __count__b__ = false;
            var __subArticles__ = default(global::Article[]);
            var __subArticles__b__ = false;

            var ____count = 0;
            reader.ReadIsBeginObjectWithVerify();
            while (!reader.ReadIsEndObjectWithSkipValueSeparator(ref ____count))
            {
                var stringKey = reader.ReadPropertyNameSegmentRaw();
                int key;
                if (!____keyMapping.TryGetValueSafe(stringKey, out key))
                {
                    reader.ReadNextBlock();
                    goto NEXT_LOOP;
                }

                switch (key)
                {
                    case 0:
                        __id__ = reader.ReadInt32();
                        __id__b__ = true;
                        break;
                    case 1:
                        __count__ = reader.ReadInt32();
                        __count__b__ = true;
                        break;
                    case 2:
                        __subArticles__ = formatterResolver.GetFormatterWithVerify<global::Article[]>().Deserialize(ref reader, formatterResolver);
                        __subArticles__b__ = true;
                        break;
                    default:
                        reader.ReadNextBlock();
                        break;
                }

                NEXT_LOOP:
                continue;
            }

            var ____result = new global::Article();
            if(__id__b__) ____result.id = __id__;
            if(__count__b__) ____result.count = __count__;
            if(__subArticles__b__) ____result.subArticles = __subArticles__;

            return ____result;
        }
    }


    public sealed class RangeFormatter : global::Utf8Json.IJsonFormatter<global::Range>
    {
        readonly global::Utf8Json.Internal.AutomataDictionary ____keyMapping;
        readonly byte[][] ____stringByteKeys;

        public RangeFormatter()
        {
            this.____keyMapping = new global::Utf8Json.Internal.AutomataDictionary()
            {
                { JsonWriter.GetEncodedPropertyNameWithoutQuotation("min"), 0},
                { JsonWriter.GetEncodedPropertyNameWithoutQuotation("max"), 1},
            };

            this.____stringByteKeys = new byte[][]
            {
                JsonWriter.GetEncodedPropertyNameWithBeginObject("min"),
                JsonWriter.GetEncodedPropertyNameWithPrefixValueSeparator("max"),
                
            };
        }

        public void Serialize(ref JsonWriter writer, global::Range value, global::Utf8Json.IJsonFormatterResolver formatterResolver)
        {
            if (value == null)
            {
                writer.WriteNull();
                return;
            }
            

            writer.WriteRaw(this.____stringByteKeys[0]);
            writer.WriteSingle(value.min);
            writer.WriteRaw(this.____stringByteKeys[1]);
            writer.WriteSingle(value.max);
            
            writer.WriteEndObject();
        }

        public global::Range Deserialize(ref JsonReader reader, global::Utf8Json.IJsonFormatterResolver formatterResolver)
        {
            if (reader.ReadIsNull())
            {
                return null;
            }
            

            var __min__ = default(float);
            var __min__b__ = false;
            var __max__ = default(float);
            var __max__b__ = false;

            var ____count = 0;
            reader.ReadIsBeginObjectWithVerify();
            while (!reader.ReadIsEndObjectWithSkipValueSeparator(ref ____count))
            {
                var stringKey = reader.ReadPropertyNameSegmentRaw();
                int key;
                if (!____keyMapping.TryGetValueSafe(stringKey, out key))
                {
                    reader.ReadNextBlock();
                    goto NEXT_LOOP;
                }

                switch (key)
                {
                    case 0:
                        __min__ = reader.ReadSingle();
                        __min__b__ = true;
                        break;
                    case 1:
                        __max__ = reader.ReadSingle();
                        __max__b__ = true;
                        break;
                    default:
                        reader.ReadNextBlock();
                        break;
                }

                NEXT_LOOP:
                continue;
            }

            var ____result = new global::Range();
            if(__min__b__) ____result.min = __min__;
            if(__max__b__) ____result.max = __max__;

            return ____result;
        }
    }

}

#pragma warning disable 168
#pragma warning restore 219
#pragma warning restore 414
#pragma warning restore 618
#pragma warning restore 612
